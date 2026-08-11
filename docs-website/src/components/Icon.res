open Xote

/* Icon geometry is taken verbatim from Lucide (ISC), inlined so the icons
   render during SSR and the site carries no icon-package dependency. */

type shape =
  | Path(string)
  | Circle({cx: string, cy: string, r: string})
  | Rect({x: string, y: string, width: string, height: string, rx: string})

type name =
  | Check
  | Copy
  | GitHub
  | Moon
  | Sun

let shapes = (name: name): array<shape> =>
  switch name {
  | Check => [Path("M20 6 9 17l-5-5")]
  | Copy => [
      Rect({x: "8", y: "8", width: "14", height: "14", rx: "2"}),
      Path("M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"),
    ]
  | GitHub => [
      Path(
        "M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 1.5-2.64-.5-5.36-.5-8 0C6 2 5 2 5 2c-.3 1.15-.3 2.35 0 3.5A5.403 5.403 0 0 0 4 9c0 3.5 3 5.5 6 5.5-.39.49-.68 1.05-.85 1.65-.17.6-.22 1.23-.15 1.85v4",
      ),
      Path("M9 18c-4.51 2-5-2-7-2"),
    ]
  | Moon => [
      Path(
        "M20.985 12.486a9 9 0 1 1-9.473-9.472c.405-.022.617.46.402.803a6 6 0 0 0 8.268 8.268c.344-.215.825-.004.803.401",
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
let make = (~name: name, ~size: string="16") =>
  <svg
    class="icon"
    ariaHidden="true"
    xmlns="http://www.w3.org/2000/svg"
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="1.75"
    strokeLinecap="round"
    strokeLinejoin="round">
    {shapes(name)->Array.map(renderShape)->View.fragment}
  </svg>
