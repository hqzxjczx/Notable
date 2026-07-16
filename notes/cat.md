# Cat Drawing

Here's a simple SVG cat you can edit or replace. The SVG is embedded directly so it renders in the editor preview.

<svg xmlns="http://www.w3.org/2000/svg" width="360" height="240" viewBox="0 0 360 240" role="img" aria-label="Cute cat">
  <!-- body -->
  <ellipse cx="180" cy="160" rx="100" ry="60" fill="#FFF0F6" stroke="#FF7AA2" stroke-width="3" stroke-linejoin="round"/>
  <!-- head -->
  <circle cx="180" cy="100" r="60" fill="#FFF0F6" stroke="#FF7AA2" stroke-width="3" stroke-linejoin="round"/>
  <!-- ears -->
  <path d="M140 60 L160 20 L170 60 Z" fill="#FFF0F6" stroke="#FF7AA2" stroke-width="3" stroke-linejoin="round"/>
  <path d="M220 60 L240 20 L250 60 Z" fill="#FFF0F6" stroke="#FF7AA2" stroke-width="3" stroke-linejoin="round"/>
  <!-- eyes (larger with highlight) -->
  <circle cx="160" cy="95" r="12" fill="#1a1a1a" />
  <circle cx="200" cy="95" r="12" fill="#1a1a1a" />
  <circle cx="154" cy="90" r="3" fill="#fff" opacity="0.9" />
  <circle cx="194" cy="90" r="3" fill="#fff" opacity="0.9" />
  <!-- nose & mouth -->
  <path d="M180 110 q6 6 12 0" stroke="#D14A6A" stroke-width="2" fill="none" stroke-linecap="round"/>
  <path d="M168 114 q12 10 24 0" stroke="#D14A6A" stroke-width="2" fill="none" stroke-linecap="round"/>
  <!-- whiskers (softer) -->
  <line x1="120" y1="105" x2="160" y2="105" stroke="#999" stroke-width="1.5" stroke-linecap="round"/>
  <line x1="120" y1="115" x2="160" y2="115" stroke="#999" stroke-width="1.5" stroke-linecap="round"/>
  <line x1="200" y1="105" x2="240" y2="105" stroke="#999" stroke-width="1.5" stroke-linecap="round"/>
  <line x1="200" y1="115" x2="240" y2="115" stroke="#999" stroke-width="1.5" stroke-linecap="round"/>
  <!-- tail -->
  <path d="M270 160 q40 -20 30 -60" stroke="#FF7AA2" stroke-width="10" fill="none" stroke-linecap="round"/>
</svg>

Feel free to edit the SVG directly in this file, or replace it with an image using Markdown image syntax: ![alt](path/to/cat.svg).