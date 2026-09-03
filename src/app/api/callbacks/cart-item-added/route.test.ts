/**
 * The three properties a Fluid callback route has to have, checked against the
 * real wrapper with real signatures.
 *
 *  1. A correctly signed request is served as the tenant the REGISTRATION binds
 *     it to.
 *  2. An unknown token is refused — and still answers 200 with the neutral
 *     body, because Fluid blocks a live checkout on this response.
 *  3. A payload naming a different company is still served as the
 *     registration's company. Tenancy comes from `registration.dri`, never from
 *     the body.
 */

import { describe, it, expect, vi, beforeEach } from "vitest";
import { tokenDigest } from "@fluid-app/droplet-sdk";

import { companyFixture, registrationFixture } from "@/test/factories";
import { signedCallbackRequest } from "@/test/signing";

const mockPrisma = vi.hoisted(() => ({
  company: { findFirst: vi.fn() },
  fluidCallbackRegistration: {
    findUnique: vi.fn(),
    upsert: vi.fn(),
    deleteMany: vi.fn(),
    count: vi.fn(),
  },
}));

vi.mock("@/lib/db", () => ({ prisma: mockPrisma, default: mockPrisma }));

const { POST } = await import("./route");

const TOKEN = "cvt_acme_token";
const OTHER_TOKEN = "cvt_someone_else";

const NEUTRAL_BODY = { success: true };

beforeEach(() => {
  vi.clearAllMocks();
  mockPrisma.fluidCallbackRegistration.findUnique.mockImplementation(
    async ({ where }: { where: { tokenDigest: string } }) =>
      where.tokenDigest === tokenDigest(TOKEN)
        ? registrationFixture({ tokenDigest: tokenDigest(TOKEN) })
        : null,
  );
});

describe("POST /api/callbacks/cart-item-added", () => {
  it("serves a correctly signed callback as the registration's tenant", async () => {
    const acme = companyFixture();
    mockPrisma.company.findFirst.mockResolvedValue(acme);

    const response = await POST(
      signedCallbackRequest({
        token: TOKEN,
        body: { cart: { token: "crt_1" }, cart_item: { id: 9 } },
      }),
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual(NEUTRAL_BODY);

    // The tenant was looked up by the registration's dri — not by anything in
    // the payload, which named no company at all.
    expect(mockPrisma.company.findFirst).toHaveBeenCalledWith({
      where: {
        dropletInstallationUuid: "dri_acme",
        active: true,
        uninstalledAt: null,
      },
    });
  });

  it("refuses an unknown token, and still answers 200 with the neutral body", async () => {
    mockPrisma.company.findFirst.mockResolvedValue(companyFixture());

    const response = await POST(
      signedCallbackRequest({ token: OTHER_TOKEN, body: { cart: {} } }),
    );

    // A 401 here would be a broken cart. The refusal is only visible in the
    // "[fluid-callback:cart-item-added] rejected" log line.
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual(NEUTRAL_BODY);

    // The handler never ran: no tenant was ever resolved.
    expect(mockPrisma.company.findFirst).not.toHaveBeenCalled();
  });

  it("returns the same body for a refusal as for a success, so it is not an oracle", async () => {
    mockPrisma.company.findFirst.mockResolvedValue(companyFixture());
    const accepted = await POST(
      signedCallbackRequest({ token: TOKEN, body: { cart: {} } }),
    );

    vi.clearAllMocks();
    mockPrisma.fluidCallbackRegistration.findUnique.mockResolvedValue(null);
    const refused = await POST(
      signedCallbackRequest({ token: OTHER_TOKEN, body: { cart: {} } }),
    );

    expect(refused.status).toBe(accepted.status);
    await expect(refused.json()).resolves.toEqual(await accepted.json());
  });

  it("serves a payload naming a different company as the registration's company", async () => {
    const acme = companyFixture();
    mockPrisma.company.findFirst.mockResolvedValue(acme);

    const response = await POST(
      signedCallbackRequest({
        token: TOKEN,
        body: {
          // Acme's token, signing a body that claims to be about company 999.
          company: { id: 999, fluid_company_id: 999 },
          cart: { token: "crt_1" },
        },
      }),
    );

    expect(response.status).toBe(200);

    // Only ever one lookup, and it used dri_acme. If the route had a payload
    // fallback, holding one tenant's token would let you act as another.
    expect(mockPrisma.company.findFirst).toHaveBeenCalledTimes(1);
    expect(mockPrisma.company.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ dropletInstallationUuid: "dri_acme" }),
      }),
    );
  });

  it("refuses a valid token whose signature was made with a different key", async () => {
    mockPrisma.company.findFirst.mockResolvedValue(companyFixture());

    const response = await POST(
      signedCallbackRequest({
        token: TOKEN,
        signingToken: "not-the-token",
        body: { cart: {} },
      }),
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual(NEUTRAL_BODY);
    expect(mockPrisma.company.findFirst).not.toHaveBeenCalled();
  });

  it("refuses when the registration resolves to no active company", async () => {
    // A company that has uninstalled, or a dri that no longer matches. The
    // wrapper treats a null principal as an auth failure, which is correct —
    // guessing a tenant would be worse than declining.
    mockPrisma.company.findFirst.mockResolvedValue(null);

    const response = await POST(
      signedCallbackRequest({ token: TOKEN, body: { cart: {} } }),
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual(NEUTRAL_BODY);
  });

  it("refuses a token issued for a definition this route does not serve", async () => {
    mockPrisma.fluidCallbackRegistration.findUnique.mockResolvedValue(
      registrationFixture({
        tokenDigest: tokenDigest(TOKEN),
        definitionName: "update_cart_tax",
      }),
    );
    mockPrisma.company.findFirst.mockResolvedValue(companyFixture());

    const response = await POST(
      signedCallbackRequest({ token: TOKEN, body: { cart: {} } }),
    );

    expect(response.status).toBe(200);
    expect(mockPrisma.company.findFirst).not.toHaveBeenCalled();
  });

  it("refuses rather than 500s when the token store is unavailable", async () => {
    mockPrisma.fluidCallbackRegistration.findUnique.mockRejectedValue(
      new Error("relation does not exist"),
    );
    mockPrisma.company.findFirst.mockResolvedValue(companyFixture());

    const response = await POST(
      signedCallbackRequest({ token: TOKEN, body: { cart: {} } }),
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual(NEUTRAL_BODY);
  });
});
