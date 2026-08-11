open Xote

// Icon geometry is taken verbatim from Lucide (ISC), inlined so the icons render
// during SSR and the site carries no icon-package dependency.
type shape =
  | Path(string)
  | Circle({cx: string, cy: string, r: string})
  | Rect({x: string, y: string, width: string, height: string, rx: string})

type name =
  | Check
  | ChevronRight
  | Copy
  | Download
  | Edit
  | ExternalLink
  | GitHub
  | Heart
  | Menu
  | Moon
  | Search
  | Star
  | Sun

type size = Sm | Md

let sizeToPixels = (size: size) =>
  switch size {
  | Sm => "16"
  | Md => "24"
  }

let shapes = (name: name): array<shape> =>
  switch name {
  | Check => [Path("M20 6 9 17l-5-5")]
  | ChevronRight => [Path("m9 18 6-6-6-6")]
  | Copy => [
      Rect({x: "8", y: "8", width: "14", height: "14", rx: "2"}),
      Path("M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"),
    ]
  | Download => [
      Path("M12 15V3"),
      Path("M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"),
      Path("m7 10 5 5 5-5"),
    ]
  | Edit => [
      Path(
        "M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z",
      ),
      Path("m15 5 4 4"),
    ]
  | ExternalLink => [
      Path("M15 3h6v6"),
      Path("M10 14 21 3"),
      Path("M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"),
    ]
  | GitHub => [
      Path(
        "M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 1.5-2.64-.5-5.36-.5-8 0C6 2 5 2 5 2c-.3 1.15-.3 2.35 0 3.5A5.403 5.403 0 0 0 4 9c0 3.5 3 5.5 6 5.5-.39.49-.68 1.05-.85 1.65-.17.6-.22 1.23-.15 1.85v4",
      ),
      Path("M9 18c-4.51 2-5-2-7-2"),
    ]
  | Heart => [
      Path(
        "M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5",
      ),
    ]
  | Menu => [Path("M4 5h16"), Path("M4 12h16"), Path("M4 19h16")]
  | Moon => [
      Path(
        "M20.985 12.486a9 9 0 1 1-9.473-9.472c.405-.022.617.46.402.803a6 6 0 0 0 8.268 8.268c.344-.215.825-.004.803.401",
      ),
    ]
  | Search => [Path("m21 21-4.34-4.34"), Circle({cx: "11", cy: "11", r: "8"})]
  | Star => [
      Path(
        "M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z",
      ),
    ]
  | Sun => [
      Circle({cx: "12", cy: "12", r: "4"}),
      Path("M12 2v2"),
      Path("M12 20v2"),
      Path("m4.93 4.93 1.41 1.41"),
      Path("m17.66 17.66 1.41 1.41"),
      Path("M2 12h2"),
      Path("M20 12h2"),
      Path("m6.34 17.66-1.41 1.41"),
      Path("m19.07 4.93-1.41 1.41"),
    ]
  }

let renderShape = (shape: shape) =>
  switch shape {
  | Path(d) => <path d />
  | Circle({cx, cy, r}) => <circle cx cy r />
  | Rect({x, y, width, height, rx}) => <rect x y width height rx />
  }

@jsx.component
let make = (~name: name, ~size: size=Md) => {
  let pixels = sizeToPixels(size)

  <svg
    class="ui-icon"
    xmlns="http://www.w3.org/2000/svg"
    width={pixels}
    height={pixels}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round">
    {shapes(name)->Array.map(renderShape)->View.fragment}
  </svg>
}
