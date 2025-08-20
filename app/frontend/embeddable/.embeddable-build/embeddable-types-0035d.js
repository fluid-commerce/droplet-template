const _ = "en-US", r = (e, o = {}) => ({
  __embeddableType: "built-in",
  toString: () => e,
  typeConfig: {
    label: e,
    optionLabel: () => e,
    ...o
  }
}), b = () => globalThis.__EMBEDDABLE_BUNDLE_HASH__ ?? null, m = (e, o) => {
  if (C.includes(e))
    throw new Error(`Type ${e} is part of the nativeTypes and cannot be defined`, { cause: "sdk" });
  const t = {
    __embeddableType: "custom",
    toString: () => e,
    typeConfig: o
  }, n = b();
  globalThis.__EMBEDDABLE__ = globalThis.__EMBEDDABLE__ || {};
  const i = n ? globalThis.__EMBEDDABLE__[n] = globalThis.__EMBEDDABLE__[n] || {} : globalThis.__EMBEDDABLE__;
  return i.types = i.types || {}, i.types = {
    ...i.types,
    [e]: {
      name: e,
      ...o
    }
  }, t;
}, L = "string", S = "number", c = "boolean", y = "time", A = "timeRange", T = "granularity", B = "dataset", f = "measure", M = "dimension", N = "dimensionOrMeasure", h = [
  L,
  S,
  c,
  y,
  A,
  T
], C = [
  ...h,
  B,
  f,
  M,
  N
], I = () => globalThis.__EMBEDDABLE_BUNDLE_HASH__ ?? null, l = (e, o) => {
  var t, n, i, d;
  const u = I();
  globalThis.__EMBEDDABLE__ ?? (globalThis.__EMBEDDABLE__ = {});
  const a = u ? (t = globalThis.__EMBEDDABLE__)[u] ?? (t[u] = {}) : globalThis.__EMBEDDABLE__;
  if (typeof e == "string")
    a.nativeTypes = a.nativeTypes || {}, a.nativeTypes[e] = a.nativeTypes[e] || {}, (n = a.nativeTypes[e]).options ?? (n.options = []), a.nativeTypes[e].options.push(o);
  else {
    const E = e.toString();
    if (!((i = a == null ? void 0 : a.types) != null && i[E]))
      return;
    (d = a.types[E]).options ?? (d.options = []), a.types[E].options.push(o);
  }
};
r("string", {
  transform: (e) => e,
  optionLabel: (e) => Array.isArray(e) ? `[${e.map((o) => `"${o}"`).join(",")}]` : `"${e}"`
});
r("number", {
  transform: (e) => Array.isArray(e) ? e : e && Number(e),
  optionLabel: (e) => Array.isArray(e) ? `[${e.join(",")}]` : (e == null ? void 0 : e.toLocaleString(_)) ?? ""
});
r("boolean", {
  transform: (e) => e === "true" || e === !0,
  optionLabel: (e) => e ? "true" : "false"
});
r("time", {
  transform: (e) => {
    const o = e != null && e.date ? new Date(e.date) : void 0;
    return {
      date: o && o.toString() !== "Invalid Date" ? o : void 0,
      relativeTimeString: e == null ? void 0 : e.relativeTimeString
    };
  },
  optionLabel: (e) => {
    var o;
    return e ? e != null && e.date ? ((o = e.date) == null ? void 0 : o.toLocaleDateString(_)) ?? e.date.toLocaleString() : e.relativeTimeString : "";
  }
});
r("timeRange", {
  transform: (e) => {
    if (!e)
      return;
    const [o, t] = [e == null ? void 0 : e.from, e == null ? void 0 : e.to], n = new Date(o), i = new Date(t);
    return {
      from: n.toString() !== "Invalid Date" ? n : void 0,
      to: i.toString() !== "Invalid Date" ? i : void 0,
      relativeTimeString: e == null ? void 0 : e.relativeTimeString
    };
  },
  optionLabel: (e) => {
    var o, t, n, i;
    return e ? e != null && e.from && e != null && e.to ? `${((o = e.from) == null ? void 0 : o.toLocaleDateString(_)) ?? ((t = e.from) == null ? void 0 : t.toLocaleString())},${((n = e.to) == null ? void 0 : n.toLocaleDateString(_)) ?? ((i = e.to) == null ? void 0 : i.toLocaleString())}` : e == null ? void 0 : e.relativeTimeString : "";
  }
});
r("granularity", {
  transform: (e) => e,
  optionLabel: (e) => e
});
r("dataset");
r("measure");
r("dimension");
r("dimensionOrMeasure");
var p = /* @__PURE__ */ ((e) => (e.NUMERIC_VALUES_ONLY = "Numeric Value Only", e.VALUE_BARS = "Value Bars", e.HEATMAP = "Heat Map", e))(p || {});
const D = m("metricsVisualizationFormat", {
  label: "Metrics visualization format",
  optionLabel: (e) => e.value
});
l(D, { value: p.NUMERIC_VALUES_ONLY });
l(D, { value: p.VALUE_BARS });
var v = /* @__PURE__ */ ((e) => (e.ASCENDING = "Ascending", e.DESCENDING = "Descending", e))(v || {});
const g = m("sortDirection", {
  label: "Sort Direction",
  optionLabel: (e) => e
});
l(g, v.ASCENDING);
l(g, v.DESCENDING);
const s = m("timeComparison", {
  label: "Time Comparison",
  optionLabel: (e) => e
});
l(s, "No comparison");
l(s, "Previous period");
l(s, "Previous week");
l(s, "Previous month");
l(s, "Previous quarter");
l(s, "Previous year");
//# sourceMappingURL=embeddable-types.js.map
