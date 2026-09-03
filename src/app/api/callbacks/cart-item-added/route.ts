/**
 * `cart_item_added` callback.
 *
 * A worked example of a real Fluid callback definition wired through
 * `withFluidCallback`. `cart_item_added` is one of the definitions in fluid at
 * app/lib/callback_definitions/cart_item_added.yml; its response schema is
 * `{ success: boolean, message?: string }`.
 *
 * A droplet forked from this template will replace the handler body. What it
 * must not replace is the shape:
 *
 *  - **Every response is 200, auth failures included.** Fluid calls this
 *    synchronously while a shopper is in checkout and blocks the storefront
 *    request on the answer, so a 401 is a broken cart rather than a protected
 *    one. The status therefore tells an operator nothing; the
 *    `[fluid-callback:…] rejected` log line is the only signal, and is what an
 *    alert should be built on.
 *  - **The failure body is identical to the no-op body.** If a refusal were
 *    distinguishable from a successful no-op, this route would be an oracle
 *    telling an attacker whether a guessed token was valid.
 *  - **The tenant comes from `registration.dri`.** Never from the payload, and
 *    never from a header. See src/lib/callbacks/store.ts.
 *
 * To actually receive traffic here, an operator syncs definitions in the admin
 * UI (Callbacks → Sync), sets this row's URL to
 * `${FLUID_DROPLET_URL}/api/callbacks/cart-item-added` and a timeout, and marks
 * it active. It is then registered for each company at install time.
 */

import { withFluidCallback } from "@fluid-app/droplet-sdk/next";
import { NextResponse } from "next/server";

import { callbackStore, resolvePrincipal } from "@/lib/callbacks";

/** The single neutral body this route ever returns. */
const ok = () => NextResponse.json({ success: true });

export const POST = withFluidCallback(
  {
    definitions: ["cart_item_added"],
    store: callbackStore,
    resolvePrincipal,
    name: "cart-item-added",
    onAuthFailure: ok,
    onInvalidBody: ok,
    onHandlerError: ok,
  },
  async ({ principal: company, definition }) => {
    // `company` is the verified tenant and `definition` is the one the
    // registration was issued for — not a field the caller declared.
    console.log(
      `[cart-item-added] company=${company.id} definition=${definition}`,
    );

    // Replace with the droplet's own work.
    return ok();
  },
);
