export const DIRECT_URL = "https://edt.iut-velizy.uvsq.fr/Home/GetCalendarData";

export const GROUPS = Object.freeze({
  "MMI1-A1": "G1-QJ2DMFYC5987",
  "MMI1-A2": "G1-PW2GUKMM5988",
  "MMI1-B1": "G1-HN2CHYNX5990",
  "MMI1-B2": "G1-QW2SJTJH5991",
  "MMI2-A1": "G1-QS2QEJVB5994",
  "MMI2-A2": "G1-EG2LDXAM5995",
  "MMI2-B1": "G1-AE2BGJHX5997",
  "MMI2-B2": "G1-TM2VJCBU5998",
  "MMI3-FA-DW-A1": "G1-TS2PGRAD6003",
  "MMI3-FA-DW-A2": "G1-KL2GMWYW6004",
  "MMI3-FI-CN-A1": "G1-EB2URAPF6006",
  "MMI3-FI-CN-A2": "G1-JP2NSAYC6007",
  "MMI3-FA-CN-A1": "G1-CC2LTGMX6000",
  "MMI3-FA-CN-A2": "G1-HW2LKCBM6001"
});

const DEFAULT_TIMEOUT_MS = 12_000;

function cleanString(value) {
  return value == null ? "" : String(value).trim();
}

export function decodeHtml(value = "") {
  const named = {
    amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ",
    eacute: "é", egrave: "è", ecirc: "ê", agrave: "à", ccedil: "ç",
    ugrave: "ù", ocirc: "ô", icirc: "î", auml: "ä", euml: "ë", iuml: "ï", ouml: "ö", uuml: "ü"
  };
  return String(value)
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .replace(/&([a-z]+);/gi, (m, name) => named[name.toLowerCase()] ?? m);
}

function stripDiacritics(value = "") {
  return String(value).normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

export function eventCategoryToTag(category = "") {
  const c = stripDiacritics(category).toLowerCase();
  if (!c) return "";
  if (c.includes("cours magistr")) return "CM";
  if (c.includes("travaux dirig")) return "TD";
  if (c.includes("travaux prati")) return "TP";
  if (c.includes("projet")) return "PROJET";
  if (c.includes("integration")) return "INT";
  if (c.includes("reunion")) return "REUNION";
  if (/\bds\b/.test(c) || c.includes("devoir surveille")) return "DS";
  if (c.includes("examen") || c.includes("partiel")) return "EXAM";
  return cleanString(category);
}

export function parseCelcatDescription(event) {
  const desc = cleanString(event?.description);
  if (!desc) return { teacher: "Inconnu", group: "Tous", rooms: [], room: "", moduleBlock: "" };

  const firstBlock = desc.split("\r\n")[0] ?? "";
  const teacherCount = firstBlock
    .split(/<br\s*\/?>/i)
    .map((p) => decodeHtml(p).trim())
    .filter(Boolean).length;

  const parts = desc
    .split(/<br\s*\/?>/i)
    .map((p) => decodeHtml(p.replace(/\r\n/g, "")).trim())
    .filter(Boolean);

  const teacherParts = parts.slice(0, teacherCount);
  if (teacherParts.length) {
    const i = teacherParts.length - 1;
    const more = teacherParts[i].match(/^\((\d+)\s+more\.\.\.\)$/i);
    if (more) teacherParts[i] = `${more[1]} autres`;
  }

  const groupIndex = teacherCount;
  const siteCount = Array.isArray(event?.sites) ? event.sites.length : 0;
  const roomStartIndex = groupIndex + 1;
  const roomEndIndex = roomStartIndex + siteCount;
  const rooms = parts.slice(roomStartIndex, roomEndIndex);

  return {
    teacher: teacherParts.join("; ") || "Inconnu",
    group: parts[groupIndex] ?? "Tous",
    rooms,
    room: rooms.join(" / "),
    moduleBlock: parts[roomEndIndex] ?? ""
  };
}

export function parseModuleFromBlock(moduleBlock = "") {
  const input = decodeHtml(cleanString(moduleBlock));
  if (!input) return { moduleCode: "", shortCode: "", moduleLabel: "", title: "" };

  const codeMatch = input.match(/\[(.*?)\]/);
  const moduleCode = codeMatch ? cleanString(codeMatch[1]) : "";
  const withoutCode = input.replace(/\s*\[.*?\]\s*$/, "").trim();
  const parts = withoutCode.split(" - ");

  if (parts.length >= 2) {
    const shortCode = parts[0].trim();
    const title = parts.slice(1).join(" - ").trim();
    return { moduleCode, shortCode, moduleLabel: `${shortCode} - ${title}`, title };
  }
  return { moduleCode, shortCode: "", moduleLabel: withoutCode, title: withoutCode };
}

function cleanRoom(value = "") {
  return cleanString(value).replace(/\s+-\s+(VEL|VELIZY|VÉLIZY)$/i, "").trim();
}

export function normalizeDirectEvent(event, publicGroup = "") {
  const desc = parseCelcatDescription(event);
  const mod = parseModuleFromBlock(desc.moduleBlock);
  const moduleCode = Array.isArray(event?.modules) && event.modules.length
    ? cleanString(event.modules[0])
    : mod.moduleCode;
  const type = eventCategoryToTag(event?.eventCategory);
  const title = mod.title || mod.shortCode || moduleCode || cleanString(event?.eventCategory) || "Sans titre";
  const rooms = desc.rooms.map(cleanRoom).filter(Boolean);

  return {
    source: "DIRECT",
    uid: cleanString(event?.id),
    start: cleanString(event?.start),
    end: cleanString(event?.end || event?.start),
    type,
    title,
    displayTitle: `${type ? `[${type}] ` : ""}${title}`,
    teacher: desc.teacher,
    group: desc.group || publicGroup,
    publicGroup,
    rooms,
    room: rooms.join(" / "),
    moduleCode,
    shortCode: mod.shortCode,
    moduleLabel: mod.moduleLabel,
    department: cleanString(event?.department),
    faculty: cleanString(event?.faculty),
    sites: Array.isArray(event?.sites) ? event.sites.map(cleanString).filter(Boolean) : []
  };
}

export async function fetchDirect(publicGroup, date, { timeoutMs = DEFAULT_TIMEOUT_MS } = {}) {
  if (!GROUPS[publicGroup]) throw new Error(`Groupe inconnu: ${publicGroup}`);

  const body = new URLSearchParams({
    start: date,
    end: date,
    resType: "103",
    calView: "agendaWeek",
    "federationIds[]": publicGroup
  });

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(DIRECT_URL, {
      method: "POST",
      headers: {
        "content-type": "application/x-www-form-urlencoded; charset=UTF-8",
        "accept": "application/json, text/javascript, */*; q=0.01",
        "x-requested-with": "XMLHttpRequest"
      },
      body,
      signal: controller.signal
    });

    if (!response.ok) throw new Error(`HTTP ${response.status} ${response.statusText}`);
    const data = await response.json();
    if (!Array.isArray(data)) throw new Error("La réponse directe n'est pas une liste d'événements.");

    // Important : [] est une réponse valide. Le fallback ne doit pas partir sur ce cas.
    return data.filter((event) => !event.allDay).map((event) => normalizeDirectEvent(event, publicGroup));
  } finally {
    clearTimeout(timer);
  }
}
