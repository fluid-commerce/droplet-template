import { describe, expect, it } from "vitest";

import {
  CallbackPathError,
  destinationPathFor,
  type CallbackPaths,
} from "@/lib/cutover/callback-paths";

const paths = (init: Partial<CallbackPaths> = {}): CallbackPaths => ({
  byName: new Map(),
  ...init,
});

describe("destinationPathFor", () => {
  it("uses the path mapped to that definition", () => {
    const p = paths({
      byName: new Map([
        ["cart_item_added", "/api/callbacks/cart-item-added"],
        ["update_cart_tax", "/api/callbacks/update-cart-tax"],
      ]),
    });

    expect(destinationPathFor("cart_item_added", p, 2)).toBe(
      "/api/callbacks/cart-item-added",
    );
    expect(destinationPathFor("update_cart_tax", p, 2)).toBe(
      "/api/callbacks/update-cart-tax",
    );
  });

  it("accepts a bare path when exactly one callback is moving", () => {
    expect(
      destinationPathFor(
        "cart_item_added",
        paths({ bare: "/api/callbacks/cart-item-added" }),
        1,
      ),
    ).toBe("/api/callbacks/cart-item-added");
  });

  // The defect this exists for: one run moves every active callback, so a bare
  // path would send two definitions to one route. The second is then refused by
  // a route holding a token for the first, behind a neutral 200 — registered,
  // "successful", and contributing nothing to the cart.
  it("refuses a bare path when more than one callback is moving", () => {
    expect(() =>
      destinationPathFor(
        "update_cart_tax",
        paths({ bare: "/api/callbacks/cart-item-added" }),
        2,
      ),
    ).toThrow(CallbackPathError);
  });

  it("names the offending definition when no path covers it", () => {
    const p = paths({
      byName: new Map([["cart_item_added", "/api/callbacks/cart-item-added"]]),
    });

    expect(() => destinationPathFor("update_cart_tax", p, 2)).toThrow(
      /update_cart_tax/,
    );
  });

  // A mapping wins over a bare path, so a mixed invocation is not ambiguous.
  it("prefers an explicit mapping over a bare path", () => {
    const p = paths({
      bare: "/api/callbacks/wrong",
      byName: new Map([["cart_item_added", "/api/callbacks/cart-item-added"]]),
    });

    expect(destinationPathFor("cart_item_added", p, 1)).toBe(
      "/api/callbacks/cart-item-added",
    );
  });
});
