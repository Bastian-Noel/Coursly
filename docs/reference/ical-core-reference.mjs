// Référence minimale du parser iCal du prototype à porter en Swift.
// L'app iOS ne doit pas exécuter ce fichier.

export function unfoldLines(text) {
  return String(text).replace(/\r?\n[ \t]/g, "");
}

export function decodeText(value = "") {
  return String(value)
    .replace(/\\n/gi, "\n")
    .replace(/\\,/g, ",")
    .replace(/\\;/g, ";")
    .replace(/\\\\/g, "\\")
    .trim();
}

function splitProperty(line) {
  const separator = line.indexOf(":");
  if (separator < 0) return [line, ""];
  return [line.slice(0, separator), line.slice(separator + 1)];
}

function propertyName(head) {
  return head.split(";")[0].toUpperCase();
}

export function parseIcal(icsText) {
  const events = [];
  let event = null;

  for (const line of unfoldLines(icsText).split(/\r?\n/)) {
    if (line === "BEGIN:VEVENT") {
      event = {};
      continue;
    }
    if (line === "END:VEVENT") {
      if (event) events.push(event);
      event = null;
      continue;
    }
    if (!event || !line) continue;

    const [head, raw] = splitProperty(line);
    const name = propertyName(head);

    if (name === "UID") event.uid = decodeText(raw);
    if (name === "SUMMARY") event.summary = decodeText(raw);
    if (name === "LOCATION") event.location = decodeText(raw);
    if (name === "DESCRIPTION") event.description = decodeText(raw);
    if (name === "DTSTART") event.startRaw = raw.trim();
    if (name === "DTEND") event.endRaw = raw.trim();
  }

  return events;
}

export function normalizeIcalEvent(event, publicGroup) {
  const summaryParts = String(event.summary || "").split(";").map((part) => part.trim());
  const titlePart = summaryParts[0] || "Sans titre";
  const titleParts = titlePart.split(" - ");
  const shortCode = titleParts.length > 1 ? titleParts[0].trim() : "";
  const title = titleParts.length > 1 ? titleParts.slice(1).join(" - ").trim() : titlePart;
  const rooms = String(event.location || "")
    .split("/")
    .map((room) => room.trim())
    .filter(Boolean);

  return {
    source: "ICAL",
    uid: event.uid || "",
    title,
    shortCode,
    rooms,
    room: rooms.join(" / "),
    description: event.description || "",
    publicGroup
  };
}

// Le prototype complet gérait également TZID/UTC et le filtrage Europe/Paris.
// Le port Swift doit utiliser Foundation pour les dates plutôt que reproduire
// naïvement les conversions JavaScript.
// Limite connue : RRULE / RECURRENCE-ID ne sont pas développés dans le prototype.
