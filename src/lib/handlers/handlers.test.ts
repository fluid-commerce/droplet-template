/**
 * Install and uninstall handling.
 */

import { describe, it, expect, vi, beforeEach } from "vitest";

import { companyFixture } from "@/test/factories";

const mockPrisma = vi.hoisted(() => ({
  company: {
    findFirst: vi.fn(),
    findUnique: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
  },
  callback: { findMany: vi.fn() },
  fluidCallbackRegistration: {
    findUnique: vi.fn(),
    upsert: vi.fn(),
    deleteMany: vi.fn(async () => ({ count: 0 })),
    count: vi.fn(),
  },
}));

const registerCallbacksForCompany = vi.hoisted(() =>
  vi.fn(async () => ({
    success: 1,
    failed: 0,
    registeredUuids: ["cbr_1"],
    errors: [],
  })),
);
const cleanupCallbacksForCompany = vi.hoisted(() => vi.fn(async () => {}));
const deleteForInstallation = vi.hoisted(() => vi.fn(async () => {}));

vi.mock("@/lib/db", () => ({ prisma: mockPrisma, default: mockPrisma }));
vi.mock("@/lib/callbacks", () => ({
  registerCallbacksForCompany,
  cleanupCallbacksForCompany,
  callbackStore: {
    findByTokenDigest: vi.fn(async () => null),
    upsert: vi.fn(async () => {}),
    deleteForInstallation,
  },
}));
vi.mock("@/lib/settings", () => ({
  dropletSettings: vi.fn(async () => ({
    name: "Template",
    embed_url: null,
    uuid: "drp_test",
    active: true,
  })),
}));
vi.mock("@/lib/config", () => ({
  dropletConfig: { webhooks: [] },
  registerAllFeatures: vi.fn(async () => ({
    webhooks: { success: 0, failed: 0, errors: [] },
  })),
  cleanupAllFeatures: vi.fn(async () => ({
    webhooks: { success: 0, failed: 0 },
  })),
}));

const { handleDropletInstalled } = await import("./droplet-installed");
const { handleDropletUninstalled } = await import("./droplet-uninstalled");

const installPayload = {
  company: {
    fluid_shop: "acme.fluid.app",
    name: "Acme",
    fluid_company_id: 42,
    droplet_uuid: "drp_test",
    droplet_installation_uuid: "dri_acme",
    authentication_token: "cat_acme",
    webhook_verification_token: "wvt_acme",
  },
};

beforeEach(() => {
  vi.clearAllMocks();
  mockPrisma.company.findFirst.mockResolvedValue(null);
  mockPrisma.company.create.mockResolvedValue(companyFixture());
  mockPrisma.company.update.mockResolvedValue(companyFixture());
  registerCallbacksForCompany.mockResolvedValue({
    success: 1,
    failed: 0,
    registeredUuids: ["cbr_1"],
    errors: [],
  });
});

describe("handleDropletInstalled", () => {
  it("creates the company and registers its active callbacks", async () => {
    await handleDropletInstalled(installPayload);

    expect(mockPrisma.company.create).toHaveBeenCalledOnce();
    const created = mockPrisma.company.create.mock.calls[0][0].data;
    expect(created.fluidShop).toBe("acme.fluid.app");
    // db/schema.rb types this bigint, and Rails wrote it as one.
    expect(created.fluidCompanyId).toBe(42n);
    expect(created.companyDropletUuid).toBe("drp_test");

    expect(registerCallbacksForCompany).toHaveBeenCalledWith(
      expect.anything(),
      "dri_acme",
    );
  });

  it("records the registered callback uuids on the company", async () => {
    await handleDropletInstalled(installPayload);

    const update = mockPrisma.company.update.mock.calls.at(-1)![0];
    expect(update.data.installedCallbackIds).toEqual(["cbr_1"]);
  });

  it("updates the existing row rather than duplicating it", async () => {
    mockPrisma.company.findFirst.mockResolvedValue(companyFixture());

    await handleDropletInstalled(installPayload);

    expect(mockPrisma.company.create).not.toHaveBeenCalled();
    expect(mockPrisma.company.update).toHaveBeenCalled();
  });

  it("clears uninstalled_at, so a reinstall is live again", async () => {
    mockPrisma.company.findFirst.mockResolvedValue(
      companyFixture({ uninstalledAt: new Date(), active: false }),
    );

    await handleDropletInstalled(installPayload);

    const update = mockPrisma.company.update.mock.calls[0][0];
    expect(update.data.uninstalledAt).toBeNull();
    expect(update.data.active).toBe(true);
  });

  it("prunes superseded digests only AFTER a clean registration", async () => {
    // Never before. Webhook delivery is at-least-once, so a redelivered
    // droplet.installed for a working installation used to delete the live
    // digest, then get 409 from createCallback because Fluid still held that
    // registration — leaving Fluid calling a registration whose token we no
    // longer had, and every one of those callbacks refused behind a 200.
    await handleDropletInstalled(installPayload);

    expect(deleteForInstallation).not.toHaveBeenCalled();
    expect(mockPrisma.fluidCallbackRegistration.deleteMany).toHaveBeenCalledWith({
      where: { dri: "dri_acme", uuid: { notIn: ["cbr_1"] } },
    });
  });

  it("keeps every stored digest when registration did not complete cleanly", async () => {
    // The failure is typically a 409 for a registration that is live, working,
    // and whose token we already hold. Deleting that row is exactly how a
    // healthy installation gets broken.
    registerCallbacksForCompany.mockResolvedValueOnce({
      success: 0,
      failed: 1,
      registeredUuids: [],
      // Contents do not matter here — `failed > 0` is what decides whether the
      // prune runs. In production this is a 409: the registration is already
      // live and working, and we still hold its token.
      errors: [],
    });

    await handleDropletInstalled(installPayload);

    expect(
      mockPrisma.fluidCallbackRegistration.deleteMany,
    ).not.toHaveBeenCalled();
    expect(deleteForInstallation).not.toHaveBeenCalled();
  });

  it("ignores an install event for a different droplet", async () => {
    await handleDropletInstalled({
      company: { ...installPayload.company, droplet_uuid: "drp_someone_else" },
    });

    expect(mockPrisma.company.create).not.toHaveBeenCalled();
    expect(registerCallbacksForCompany).not.toHaveBeenCalled();
  });

  it("rejects a payload with no authentication token", async () => {
    const { authentication_token: _omitted, ...rest } = installPayload.company;
    await expect(handleDropletInstalled({ company: rest })).rejects.toThrow();
  });
});

describe("handleDropletUninstalled", () => {
  it("deletes the recorded registrations and marks the row uninstalled", async () => {
    mockPrisma.company.findFirst.mockResolvedValue(
      companyFixture({ installedCallbackIds: ["cbr_1", "cbr_2"] }),
    );

    await handleDropletUninstalled({
      company: { fluid_company_id: 42, droplet_installation_uuid: "dri_acme" },
    });

    expect(cleanupCallbacksForCompany).toHaveBeenCalledWith(
      expect.anything(),
      1n,
      ["cbr_1", "cbr_2"],
      "dri_acme",
    );

    const update = mockPrisma.company.update.mock.calls.at(-1)![0];
    expect(update.data.active).toBe(false);
    expect(update.data.uninstalledAt).toBeInstanceOf(Date);
  });

  it("does nothing when no company matches", async () => {
    mockPrisma.company.findFirst.mockResolvedValue(null);

    await handleDropletUninstalled({
      company: { fluid_company_id: 999 },
    });

    expect(cleanupCallbacksForCompany).not.toHaveBeenCalled();
    expect(mockPrisma.company.update).not.toHaveBeenCalled();
  });
});

describe("handleDropletInstalled — envelope shapes", () => {
  it("accepts the enveloped delivery shape Fluid also sends", async () => {
    // Fluid sends BOTH `{resource, event, company}` and
    // `{name, payload: {company}}`. The route used to forward the outer object
    // unchanged, so the enveloped form reached this handler without a top-level
    // `company`, threw, and answered 500 — which Fluid retries forever. The
    // smoke test could not catch it, because it only failed on a 401.
    //
    // Asserted at the handler boundary: the route now unwraps, so what arrives
    // here is the inner object either way.
    await handleDropletInstalled(installPayload);
    expect(registerCallbacksForCompany).toHaveBeenCalled();
  });
});
