import type { GoldieConfig } from "goldie";

const APP_ROOT = "/Users/igorvaryvoda/Projects/Ortholinear";

const config: GoldieConfig = {
  appRoot: APP_ROOT,
  // Release simulator build: xcodebuild -scheme Ortholinear -configuration Release
  //   -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd-goldie build
  appPath: `${APP_ROOT}/build/dd-goldie/Build/Products/Release-iphonesimulator/Ortholinear.app`,
  bundleId: "com.varyvoda.Ortholinear",

  devices: ["iphone-6.9"],
  locales: ["en-US"],
  appearance: "light",

  // The app's own palette: warm paper and deep teal (App/ContentView.swift).
  frame: { variant: "17-pro-silver" },
  theme: {
    background: "linear-gradient(165deg, #E4EFEA 0%, #F5F2EB 55%, #FBF9F4 100%)",
    headlineColor: "#15201E",
    subheadColor: "#4F5E5A",
    fontFamily: '-apple-system, "SF Pro Display", system-ui, sans-serif',
    copyHeightRatio: 0.24,
    deviceWidthRatio: 0.84,
    template: ["classic", "offset", "tilt", "classic", "tilt-right", "copy-below"],
    layout: "classic",
  },

  store: {
    name: "Ortholinear Keyboard",
    subtitle: { "en-US": "Big keys. Ukrainian + English" },
    developer: "Igor Varyvoda",
    category: "Utilities",
    rating: 4.8,
    ratingCount: "New",
    ageRating: "4+",
    price: "Free",
    description: {
      "en-US":
        "Big fingers deserve room to type. Ortholinear gives every letter a wider key in straight rows, with key height, letter size and spacing you set yourself.\n\nUkrainian and English, plus 13 more layouts. Suggestions change a word only when you tap one, glide typing works in English and Ukrainian, and sentences start with a capital on their own.\n\nNo Full Access, no network, no tracking. Your words stay on your iPhone.",
    },
  },

  scenes: [
    {
      kind: "screenshot",
      id: "type",
      flow: "store-01-type",
      headline: { "en-US": "Bigger keys" },
      subhead: { "en-US": "Straight rows give every letter a wider key. Ukrainian, English and 13 more." },
    },
    {
      kind: "screenshot",
      id: "suggest",
      flow: "store-02-suggest",
      headline: { "en-US": "Tap-only suggestions" },
      subhead: { "en-US": "Nothing changes unless you choose it. All on your iPhone." },
    },
    {
      kind: "screenshot",
      id: "languages",
      flow: "store-03-languages",
      headline: { "en-US": "15 languages" },
      subhead: { "en-US": "Ukrainian first, plus Polish, German, French and more." },
    },
    {
      kind: "screenshot",
      id: "themes",
      flow: "store-04-themes",
      headline: { "en-US": "Make it yours" },
      subhead: { "en-US": "Seven themes, including Tokyo Night and Nord." },
    },
    {
      kind: "screenshot",
      id: "settings",
      flow: "store-05-settings",
      headline: { "en-US": "Size every key" },
      subhead: { "en-US": "Key height, letter size and spacing, with a live preview." },
    },
    {
      kind: "screenshot",
      id: "private",
      flow: "store-06-private",
      headline: { "en-US": "Private by design" },
      subhead: { "en-US": "No Full Access. No network. Your words stay yours." },
    },
    {
      kind: "preview",
      id: "preview",
      segments: [
        { id: "type", flow: "store-preview-01-type" },
        { id: "glide", flow: "store-preview-02-glide" },
        { id: "theme", flow: "store-preview-03-theme", holdSeconds: 1.5 },
      ],
    },
  ],
};

export default config;
