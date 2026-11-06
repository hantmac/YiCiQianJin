# Third-party content

## Word Atlas（词光）

- Source: https://github.com/designfuchen/word-atlas
- Used: illustrations (`YiCiQianJin/Illustrations/*.webp`, 512px originals, unmodified),
  example sentences with Chinese translations and usage tips (`YiCiQianJin/Data/atlas.json`),
  for the words that also appear in this app's word books.
- Attribution: **Word Atlas contributors — CC BY 4.0**
  (https://creativecommons.org/licenses/by/4.0/)
- Changes: entries were selected to match our word lists and re-serialized into a compact JSON
  format; text and images are otherwise unchanged.
- Upstream note: the content was generated with AI models, checked automatically and not
  proofread entry by entry; provided as-is without warranty.

Regenerate with `python3 scripts/import_word_atlas.py <path-to-word-atlas-checkout>`.

Attribution for users is given in the App Store description ("插画与例句来自 Word Atlas contributors（词光），CC BY 4.0").
