export interface TravellingPet { hunger_paused_until?: string | null; last_fed_at?: string | null; created_at?: string }

export function isPetTravelling(pet: TravellingPet | null | undefined, now = Date.now()): boolean {
  return !!pet?.hunger_paused_until && Date.parse(pet.hunger_paused_until) > now
}

export function hungerReference(pet: TravellingPet): string | null {
  const reference = pet.last_fed_at || pet.created_at || null
  return pet.hunger_paused_until && (!reference || Date.parse(pet.hunger_paused_until) > Date.parse(reference))
    ? pet.hunger_paused_until : reference
}
