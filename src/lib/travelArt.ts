import postcards from '../data/travelPostcards.json'

const art = (name: string) => `/assets/travel/${name}.webp`

export function destinationArt(id: string) {
  return art(id === 'forest' ? 'forest-day' : id === 'coast' ? 'coast-day' : 'stars-camp')
}

// Bind to the story itself so a catalogue reorder cannot swap illustrations.
export function postcardArt(id: string, story: string) {
  return postcards.find(card => card.destination === id && card.story === story)?.image
}
