// Référence de stratégie à porter en Swift.
// Règle absolue : POST = source de vérité ; iCal = fallback uniquement.

export async function loadCalendar({ fetchDirect, fetchIcal, group, date }) {
  try {
    const directEvents = await fetchDirect(group, date);

    // Une liste vide est un succès valide.
    return {
      source: "DIRECT",
      events: directEvents,
      fallbackReason: null
    };
  } catch (directError) {
    const icalEvents = await fetchIcal(group, date);
    return {
      source: "ICAL",
      events: icalEvents,
      fallbackReason: String(directError?.message || directError)
    };
  }
}

// À ne JAMAIS faire :
// const merged = [...directEvents, ...icalEvents];
// const completed = enrichDirectWithIcal(directEvents, icalEvents);
