# Travel illustrations

Generated with the built-in image_gen tool, 2026-09-07. Destination assets are in `public/assets/travel/`, optimized to 1200px-wide WebP (quality 85). Original generated PNGs remain outside the repository.

The postcard album now uses **36 individually generated scenery illustrations**, one per story, in `public/assets/travel/scenes/` (960px-wide WebP, quality 84). `src/data/travelPostcards.json` maps exact destination + story text to its image, independently of server catalogue ordering. The user selected scenery-only artwork: do not composite a pet sprite over the scene. Pet attribution, when available, is displayed in the written signature. Complete prompts and source paths are recorded in `docs/postcard-background-generation.json`. Earlier rabbit illustrations and their prompts remain as unused originals.

## Prompt set

Each prompt used this prefix, the scene below, and the shared suffix:

Prefix: Use case: illustration-story. Asset: full bleed wide landscape banner for a children's virtual pet travel game, approximately 2:1 composition.

- `forest-day.webp`: A tiny cute squirrel explorer with a green backpack crossing a mossy wooden bridge above a sparkling stream, lush rounded forest trees, mushrooms, wildflowers, butterflies, sunbeams and a little distant woodland tent.
- `forest-night.webp`: A cute fluffy bunny camping in a lush enchanted forest at twilight, cozy glowing canvas tent, a lantern, hundreds of gentle fireflies, fern leaves, mushrooms and a tiny snail. Magical teal green and warm amber light.
- `coast-day.webp`: A tiny cute corgi explorer building an elaborate seashell sandcastle on a turquoise bay beach, smiling little crab, pastel shells, soft foamy waves, red roof lighthouse and rounded clouds in the distance. Sunny joyful aqua and peach palette.
- `coast-sunset.webp`: A cute fluffy squirrel and little bunny sitting together on a wooden seaside pier watching an apricot pink sunset over a sparkling ocean, a small picnic basket and seashells, distant lighthouse, soft dreamy clouds. Cozy warm coral and lavender.
- `stars-camp.webp`: A cute small bunny explorer wrapped in a blanket outside a warmly glowing tent on a grassy mountain overlook, enormous sparkling indigo starry sky, luminous crescent moon, soft purple mountains, little telescope and wildflowers. Dreamy and cozy.
- `stars-dawn.webp`: A cute small red panda explorer with a backpack standing on a flower-covered mountain hill watching a magical meteor shower fading into lavender peach dawn, rolling misty valleys, tiny lantern and winding path. Wonder and adventure.

Suffix: Premium highly polished cute cartoon storybook illustration, soft rounded forms, expressive adorable animals, painterly 3D-like volume with delicate hand painted textures, rich layered environment, tiny delightful details, harmonious pastel colors, beautiful cinematic soft lighting. Broad scenic composition, subject in central safe area, readable at small size. NOT flat geometric vector, NOT emoji, NOT photorealistic. No text, letters, numbers, logos, border, collage or watermark.
