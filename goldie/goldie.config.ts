import type { GoldieConfig } from "goldie";

const APP_ROOT = "/Users/igorvaryvoda/Projects/Ortholinear";

// Headlines and subheads per App Store locale; the listings themselves are in docs/listing.
const COPY: Record<string, Record<string, [string, string]>> = {
  "en-US": {
    "type": [
      "Bigger keys",
      "Straight rows give every letter a wider key. Ukrainian, English and 13 more."
    ],
    "suggest": [
      "Tap-only suggestions",
      "Nothing changes unless you choose it. All on your iPhone."
    ],
    "languages": [
      "15 languages",
      "Ukrainian first, plus Polish, German, French and more."
    ],
    "themes": [
      "Make it yours",
      "Seven themes, including Tokyo Night and Nord."
    ],
    "settings": [
      "Size every key",
      "Key height, letter size and spacing, with a live preview."
    ],
    "private": [
      "Private by design",
      "No Full Access. No network. Your words stay yours."
    ]
  },
  "uk": {
    "type": [
      "Більші клавіші",
      "Рівні ряди дають кожній літері ширшу клавішу. Українська, англійська і ще 13."
    ],
    "suggest": [
      "Підказки лише за дотиком",
      "Нічого не зміниться, доки ви не оберете. Усе на вашому iPhone."
    ],
    "languages": [
      "15 мов",
      "Українська — перша, а ще польська, німецька, французька та інші."
    ],
    "themes": [
      "Зробіть її своєю",
      "Сім тем, серед них Tokyo Night і Nord."
    ],
    "settings": [
      "Розмір кожної клавіші",
      "Висота клавіш, розмір літер і відступи з живим переглядом."
    ],
    "private": [
      "Приватна за задумом",
      "Без повного доступу. Без мережі. Ваші слова — ваші."
    ]
  },
  "pl": {
    "type": [
      "Większe klawisze",
      "Proste rzędy dają każdej literze szerszy klawisz. Polski, ukraiński, angielski i więcej."
    ],
    "suggest": [
      "Podpowiedzi tylko na dotyk",
      "Nic się nie zmienia, dopóki sam nie wybierzesz. Wszystko na iPhonie."
    ],
    "languages": [
      "15 języków",
      "Od razu po polsku, a do tego ukraiński, angielski, niemiecki i inne."
    ],
    "themes": [
      "Po Twojemu",
      "Siedem motywów, w tym Tokyo Night i Nord."
    ],
    "settings": [
      "Dopasuj każdy klawisz",
      "Wysokość klawiszy, rozmiar liter i odstępy z podglądem na żywo."
    ],
    "private": [
      "Prywatna z założenia",
      "Bez pełnego dostępu. Bez sieci. Twoje słowa zostają u Ciebie."
    ]
  },
  "cs": {
    "type": [
      "Větší klávesy",
      "Rovné řady dávají každému písmenu širší klávesu. Čeština, ukrajinština, angličtina a další."
    ],
    "suggest": [
      "Návrhy jen na klepnutí",
      "Nic se nezmění, dokud si nevyberete. Vše ve vašem iPhonu."
    ],
    "languages": [
      "15 jazyků",
      "Čeština hned od začátku, k tomu ukrajinština, angličtina, němčina a další."
    ],
    "themes": [
      "Podle vašeho gusta",
      "Sedm motivů, mezi nimi Tokyo Night a Nord."
    ],
    "settings": [
      "Každá klávesa na míru",
      "Výška kláves, velikost písma a mezery s živým náhledem."
    ],
    "private": [
      "Soukromí od základu",
      "Bez plného přístupu. Bez sítě. Vaše slova zůstanou vaše."
    ]
  },
  "sk": {
    "type": [
      "Väčšie klávesy",
      "Rovné rady dávajú každému písmenu širšiu klávesu. Slovenčina, ukrajinčina, angličtina a ďalšie."
    ],
    "suggest": [
      "Návrhy len na ťuknutie",
      "Nič sa nezmení, kým si nevyberiete. Všetko vo vašom iPhone."
    ],
    "languages": [
      "15 jazykov",
      "Slovenčina hneď od začiatku, k tomu ukrajinčina, angličtina, nemčina a ďalšie."
    ],
    "themes": [
      "Podľa vašej chuti",
      "Sedem motívov vrátane Tokyo Night a Nord."
    ],
    "settings": [
      "Každá klávesa na mieru",
      "Výška kláves, veľkosť písma a medzery so živým náhľadom."
    ],
    "private": [
      "Súkromie od základu",
      "Bez plného prístupu. Bez siete. Vaše slová zostanú vaše."
    ]
  },
  "hr": {
    "type": [
      "Veće tipke",
      "Ravni redovi daju svakom slovu širu tipku. Hrvatski, ukrajinski, engleski i drugi."
    ],
    "suggest": [
      "Prijedlozi samo na dodir",
      "Ništa se ne mijenja dok sami ne odaberete. Sve na vašem iPhoneu."
    ],
    "languages": [
      "15 jezika",
      "Hrvatski od početka, uz ukrajinski, engleski, njemački i druge."
    ],
    "themes": [
      "Neka bude vaša",
      "Sedam tema, među njima Tokyo Night i Nord."
    ],
    "settings": [
      "Svaka tipka po mjeri",
      "Visina tipki, veličina slova i razmaci uz pregled uživo."
    ],
    "private": [
      "Privatnost od temelja",
      "Bez punog pristupa. Bez mreže. Vaše riječi ostaju vaše."
    ]
  },
  "de-DE": {
    "type": [
      "Größere Tasten",
      "Gerade Reihen geben jedem Buchstaben eine breitere Taste. Deutsch, Ukrainisch, Englisch und mehr."
    ],
    "suggest": [
      "Vorschläge nur per Tipp",
      "Nichts ändert sich, bis du es auswählst. Alles auf deinem iPhone."
    ],
    "languages": [
      "15 Sprachen",
      "Deutsch von Anfang an, dazu Ukrainisch, Englisch, Polnisch und mehr."
    ],
    "themes": [
      "Mach sie zu deiner",
      "Sieben Themes, darunter Tokyo Night und Nord."
    ],
    "settings": [
      "Jede Taste nach Maß",
      "Tastenhöhe, Schriftgröße und Abstände mit Live-Vorschau."
    ],
    "private": [
      "Privat von Grund auf",
      "Kein voller Zugriff. Kein Netzwerk. Deine Worte bleiben deine."
    ]
  },
  "nl-NL": {
    "type": [
      "Grotere toetsen",
      "Rechte rijen geven elke letter een bredere toets. Nederlands, Oekraïens, Engels en meer."
    ],
    "suggest": [
      "Suggesties alleen met een tik",
      "Er verandert niets tot jij kiest. Alles op je iPhone."
    ],
    "languages": [
      "15 talen",
      "Meteen in het Nederlands, plus Oekraïens, Engels, Duits en meer."
    ],
    "themes": [
      "Helemaal van jou",
      "Zeven thema's, waaronder Tokyo Night en Nord."
    ],
    "settings": [
      "Elke toets op maat",
      "Toetshoogte, lettergrootte en afstand, met live voorbeeld."
    ],
    "private": [
      "Privé vanaf de basis",
      "Geen volledige toegang. Geen netwerk. Jouw woorden blijven van jou."
    ]
  },
  "da": {
    "type": [
      "Større taster",
      "Lige rækker giver hvert bogstav en bredere tast. Dansk, ukrainsk, engelsk og flere."
    ],
    "suggest": [
      "Forslag kun med et tryk",
      "Intet ændres, før du vælger det. Alt foregår på din iPhone."
    ],
    "languages": [
      "15 sprog",
      "Dansk fra start, plus ukrainsk, engelsk, tysk og flere."
    ],
    "themes": [
      "Gør det til dit eget",
      "Syv temaer, blandt andet Tokyo Night og Nord."
    ],
    "settings": [
      "Tilpas hver tast",
      "Tasthøjde, bogstavstørrelse og afstand med live-visning."
    ],
    "private": [
      "Privat fra bunden",
      "Ingen fuld adgang. Intet netværk. Dine ord forbliver dine."
    ]
  },
  "sv": {
    "type": [
      "Större tangenter",
      "Raka rader ger varje bokstav en bredare tangent. Svenska, ukrainska, engelska och fler."
    ],
    "suggest": [
      "Förslag bara när du trycker",
      "Inget ändras förrän du väljer. Allt sker på din iPhone."
    ],
    "languages": [
      "15 språk",
      "Svenska från start, plus ukrainska, engelska, tyska och fler."
    ],
    "themes": [
      "Gör det till ditt",
      "Sju teman, bland annat Tokyo Night och Nord."
    ],
    "settings": [
      "Anpassa varje tangent",
      "Tangenthöjd, bokstavsstorlek och avstånd med förhandsvisning."
    ],
    "private": [
      "Privat i grunden",
      "Ingen fullständig åtkomst. Inget nätverk. Dina ord är dina."
    ]
  },
  "no": {
    "type": [
      "Større taster",
      "Rette rader gir hver bokstav en bredere tast. Norsk, ukrainsk, engelsk og flere."
    ],
    "suggest": [
      "Forslag bare med et trykk",
      "Ingenting endres før du velger det. Alt skjer på din iPhone."
    ],
    "languages": [
      "15 språk",
      "Norsk fra start, pluss ukrainsk, engelsk, tysk og flere."
    ],
    "themes": [
      "Gjør det til ditt",
      "Sju temaer, blant annet Tokyo Night og Nord."
    ],
    "settings": [
      "Tilpass hver tast",
      "Tasthøyde, bokstavstørrelse og avstand med forhåndsvisning."
    ],
    "private": [
      "Privat fra grunnen av",
      "Ingen full tilgang. Ikke noe nettverk. Ordene dine er dine."
    ]
  },
  "fr-FR": {
    "type": [
      "Des touches plus grandes",
      "Des rangées droites donnent à chaque lettre une touche plus large. Français, ukrainien, anglais et plus."
    ],
    "suggest": [
      "Suggestions au toucher",
      "Rien ne change sans votre choix. Tout reste sur votre iPhone."
    ],
    "languages": [
      "15 langues",
      "Le français d’emblée, plus l’ukrainien, l’anglais, l’allemand et d’autres."
    ],
    "themes": [
      "À votre image",
      "Sept thèmes, dont Tokyo Night et Nord."
    ],
    "settings": [
      "Chaque touche sur mesure",
      "Hauteur des touches, taille des lettres et espacement, avec aperçu en direct."
    ],
    "private": [
      "Privé par conception",
      "Sans accès complet. Sans réseau. Vos mots restent les vôtres."
    ]
  },
  "fr-CA": {
    "type": [
      "Des touches plus grandes",
      "Des rangées droites donnent à chaque lettre une touche plus large. Français en QWERTY, ukrainien, anglais et plus."
    ],
    "suggest": [
      "Suggestions au toucher",
      "Rien ne change sans votre choix. Tout reste sur votre iPhone."
    ],
    "languages": [
      "15 langues",
      "Le français d’emblée, en QWERTY canadien, plus l’ukrainien, l’anglais et d’autres."
    ],
    "themes": [
      "À votre image",
      "Sept thèmes, dont Tokyo Night et Nord."
    ],
    "settings": [
      "Chaque touche sur mesure",
      "Hauteur des touches, taille des lettres et espacement, avec aperçu en direct."
    ],
    "private": [
      "Privé par conception",
      "Sans accès complet. Sans réseau. Vos mots restent les vôtres."
    ]
  },
  "es-ES": {
    "type": [
      "Teclas más grandes",
      "Filas rectas que dan a cada letra una tecla más ancha. Español, ucraniano, inglés y más."
    ],
    "suggest": [
      "Sugerencias solo al tocar",
      "Nada cambia hasta que tú lo eliges. Todo en tu iPhone."
    ],
    "languages": [
      "15 idiomas",
      "Español desde el principio, además de ucraniano, inglés, alemán y más."
    ],
    "themes": [
      "Hazlo tuyo",
      "Siete temas, entre ellos Tokyo Night y Nord."
    ],
    "settings": [
      "Cada tecla a tu medida",
      "Altura de las teclas, tamaño de letra y espaciado, con vista previa en directo."
    ],
    "private": [
      "Privado por diseño",
      "Sin acceso total. Sin red. Tus palabras son tuyas."
    ]
  },
  "es-MX": {
    "type": [
      "Teclas más grandes",
      "Filas rectas que dan a cada letra una tecla más ancha. Español, ucraniano, inglés y más."
    ],
    "suggest": [
      "Sugerencias solo al tocar",
      "Nada cambia hasta que tú lo eliges. Todo en tu iPhone."
    ],
    "languages": [
      "15 idiomas",
      "Español desde el principio, además de ucraniano, inglés, alemán y más."
    ],
    "themes": [
      "Hazlo tuyo",
      "Siete temas, entre ellos Tokyo Night y Nord."
    ],
    "settings": [
      "Cada tecla a tu medida",
      "Altura de las teclas, tamaño de letra y espaciado, con vista previa en vivo."
    ],
    "private": [
      "Privado por diseño",
      "Sin acceso total. Sin red. Tus palabras son tuyas."
    ]
  }
};
const locales = Object.keys(COPY);
const copy = (scene: string, part: 0 | 1) =>
  Object.fromEntries(locales.map((locale) => [locale, COPY[locale][scene][part]]));
const subtitles: Record<string, string> = {
  "en-US": "Big keys. Ukrainian + English",
  "uk": "Великі клавіші. Українська",
  "pl": "Duże klawisze. Polski układ",
  "cs": "Velké klávesy pro češtinu",
  "sk": "Veľké klávesy pre slovenčinu",
  "hr": "Velike tipke za hrvatski",
  "de-DE": "Große Tasten auf Deutsch",
  "nl-NL": "Grote toetsen. Nederlands",
  "da": "Store taster på dansk",
  "sv": "Stora tangenter för svenska",
  "no": "Store taster for norsk",
  "fr-FR": "Grandes touches en français",
  "fr-CA": "Grandes touches, en français",
  "es-ES": "Teclas grandes, en español",
  "es-MX": "Teclas grandes, en español"
};

const config: GoldieConfig = {
  appRoot: APP_ROOT,
  // Release simulator build: xcodebuild -scheme Ortholinear -configuration Release
  //   -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd-goldie build
  appPath: `${APP_ROOT}/build/dd-goldie/Build/Products/Release-iphonesimulator/Ortholinear.app`,
  bundleId: "com.varyvoda.Ortholinear",

  devices: ["iphone-6.9"],
  locales: locales,
  // The keyboard starts in each locale's own layout, so each locale has its own captures (Tools/store-capture.py).
  localizedCaptures: true,
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
    subtitle: subtitles,
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
      headline: copy("type", 0),
      subhead: copy("type", 1),
    },
    {
      kind: "screenshot",
      id: "suggest",
      flow: "store-02-suggest",
      headline: copy("suggest", 0),
      subhead: copy("suggest", 1),
    },
    {
      kind: "screenshot",
      id: "languages",
      flow: "store-03-languages",
      headline: copy("languages", 0),
      subhead: copy("languages", 1),
    },
    {
      kind: "screenshot",
      id: "themes",
      flow: "store-04-themes",
      headline: copy("themes", 0),
      subhead: copy("themes", 1),
    },
    {
      kind: "screenshot",
      id: "settings",
      flow: "store-05-settings",
      headline: copy("settings", 0),
      subhead: copy("settings", 1),
    },
    {
      kind: "screenshot",
      id: "private",
      flow: "store-06-private",
      headline: copy("private", 0),
      subhead: copy("private", 1),
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
