"use client";

import { HugeiconsIcon, type IconSvgElement } from "@hugeicons/react";
import {
  AlertCircleIcon,
  AntennaIcon,
  AppleFinderIcon,
  AppleIcon,
  ArrowDown03Icon,
  ArrowRight02Icon,
  BoltIcon,
  BulbIcon,
  CheckIcon,
  CheckmarkCircle02Icon,
  CircleIcon,
  Clock01Icon,
  CubeIcon,
  Database01Icon,
  DollarSignIcon,
  FeatherIcon,
  File02Icon,
  FlaskConicalIcon,
  GithubIcon,
  HistoryIcon,
  IceCubesIcon,
  Key01Icon,
  Layout03Icon,
  Link01Icon,
  LockKeyIcon,
  MicrochipIcon,
  Moon02Icon,
  MountainIcon,
  NeuralNetworkIcon,
  PauseIcon,
  PlayIcon,
  PythonIcon,
  ReloadIcon,
  SaveIcon,
  Search01Icon,
  Settings02Icon,
  ShieldHalfIcon,
  SparklesIcon,
  StarIcon,
  Sun01Icon,
  TableColumnsSplitIcon,
  TokenCircleIcon,
  WorkflowSquare07Icon,
  Wrench01Icon,
} from "@hugeicons/core-free-icons";

const ICONS = {
  search: Search01Icon,
  settings: Settings02Icon,
  key: Key01Icon,
  play: PlayIcon,
  pause: PauseIcon,
  sun: Sun01Icon,
  moon: Moon02Icon,
  layout: Layout03Icon,
  clock: Clock01Icon,
  dollar: DollarSignIcon,
  tokens: TokenCircleIcon,
  lightbulb: BulbIcon,
  database: Database01Icon,
  link: Link01Icon,
  tool: Wrench01Icon,
  error: AlertCircleIcon,
  save: SaveIcon,
  timeTravel: HistoryIcon,
  "diagram-project": WorkflowSquare07Icon,
  bolt: BoltIcon,
  "shield-halved": ShieldHalfIcon,
  "clock-rotate-left": HistoryIcon,
  "table-columns": TableColumnsSplitIcon,
  "file-lines": File02Icon,
  "arrow-down-long": ArrowDown03Icon,
  "arrow-right": ArrowRight02Icon,
  "circle-nodes": NeuralNetworkIcon,
  spark: SparklesIcon,
  "mountain-sun": MountainIcon,
  flask: FlaskConicalIcon,
  cube: CubeIcon,
  cubes: IceCubesIcon,
  microchip: MicrochipIcon,
  feather: FeatherIcon,
  lock: LockKeyIcon,
  "tower-broadcast": AntennaIcon,
  check: CheckIcon,
  "check-circle": CheckmarkCircle02Icon,
  dot: CircleIcon,
  circle: CircleIcon,
  "circle-dot": CircleIcon,
  rotate: ReloadIcon,
  gear: Settings02Icon,
  "circle-exclamation": AlertCircleIcon,
  github: GithubIcon,
  star: StarIcon,
  apple: AppleIcon,
  "apple-finder": AppleFinderIcon,
  python: PythonIcon,
} as const satisfies Record<string, IconSvgElement>;

/** Supported icon names for Tether web components. */
export type IconName = keyof typeof ICONS;

/**
 * Renders a Hugeicons glyph using the local icon name map.
 */
export function Icon({
  name,
  size = 14,
  strokeWidth = 1.8,
  className,
}: {
  name: IconName;
  size?: number | string;
  strokeWidth?: number;
  className?: string;
}) {
  return (
    <HugeiconsIcon
      aria-hidden="true"
      className={className}
      color="currentColor"
      icon={ICONS[name]}
      size={size}
      strokeWidth={strokeWidth}
    />
  );
}
