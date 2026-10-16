import { z } from 'zod';

const color = z.string().regex(/^#[0-9a-fA-F]{6}$/, 'must be a #rrggbb color');
export const idSchema = z.string().regex(/^[a-z0-9_]{1,32}$/, 'must match ^[a-z0-9_]{1,32}$');
/** Option ids inside the ink look; "" means "none" for optional slots (hat, eyewear, ...). */
const optId = z.string().regex(/^[a-z0-9_]{0,32}$/, 'must match ^[a-z0-9_]{0,32}$');

/**
 * Signature parts of the hand-drawn look: each unlocks with the themed outfit (character
 * collectible) it comes from. Mirrors client/scripts/render/ink/ink_look.gd SIGNATURE.
 */
export const SIGNATURE_PARTS: Record<string, Record<string, string>> = {
  hat: { viking: 'bjorn', pirate: 'pirate', wizard: 'wizard', dino: 'dino', antenna: 'bolt', helmet: 'astronaut', helm: 'knight' },
  eyewear: { visor: 'bolt', patch: 'pirate' },
  back: { cape: 'knight', wings: 'astronaut' },
  companion: { drone: 'bolt', bird: 'pirate', star: 'wizard', dino: 'dino', ghost: 'skeleton' },
  club: { laser: 'bolt', golden: 'knight', bone: 'skeleton' },
  pantsPattern: { stars: 'wizard', flames: 'cowboy' },
};

export const DRAWING_LIMITS = { strokes: 48, points: 1500 } as const;

/** One stroke of a clothing drawing: colour, width, alpha, and quantised (x, y) pairs 0..1000. */
const StrokeSchema = z.strictObject({
  c: color,
  w: z.number().min(0.4).max(9),
  a: z.number().min(0.1).max(1),
  p: z.array(z.number().int().min(0).max(1000)).min(2).max(DRAWING_LIMITS.points * 2),
});

/** A player drawing on one garment (docs/INK_ART_SPEC.md §8). */
const DrawingSchema = z
  .strictObject({
    v: z.literal(1),
    legs: z.enum(['both', 'front']),
    strokes: z.array(StrokeSchema).max(DRAWING_LIMITS.strokes),
  })
  .refine((d) => d.strokes.reduce((n, s) => n + Math.floor(s.p.length / 2), 0) <= DRAWING_LIMITS.points, {
    message: `a drawing may have at most ${DRAWING_LIMITS.points} points`,
  });

/** The hand-drawn look (Appearance v2 `ink`). Mirrors client/scripts/render/ink/ink_look.gd. */
export const InkSchema = z.strictObject({
  hair: optId,
  hairColor: z.union([color, z.literal('')]),
  headFill: optId,
  eyes: optId,
  brows: optId,
  mouth: optId,
  mark: optId,
  pantsCut: optId,
  pantsColor: color,
  pantsColor2: color,
  pantsPattern: optId,
  pantsLength: z.number().min(0.45).max(1),
  pantsFlare: z.number().min(0.6).max(1.8),
  pantsWaist: z.number().min(-4).max(4),
  pantsCuff: optId,
  top: optId,
  topColor: color,
  topColor2: color,
  hat: optId,
  hatColor: color,
  eyewear: optId,
  eyewearColor: color,
  neck: optId,
  neckColor: color,
  back: optId,
  backColor: color,
  gloves: optId,
  glovesColor: color,
  shoes: optId,
  shoesColor: color,
  companion: optId,
  club: optId,
  drawings: z.strictObject({
    pants: DrawingSchema.optional(),
    top: DrawingSchema.optional(),
    hat: DrawingSchema.optional(),
  }),
});

/**
 * Appearance (API.md §1.3). Unknown keys are rejected. v1 keys stay required so older clients
 * keep working; v2 adds the optional hand-drawn `ink` look.
 */
export const AppearanceSchema = z.strictObject({
  v: z.union([z.literal(1), z.literal(2)]),
  /** Themed outfit id ("stickman" or a former roster id). Optional for older clients. */
  character: idSchema.optional(),
  bodyColor: color,
  outlineColor: color,
  headShape: idSchema,
  headScale: z.number().min(0.8).max(1.3),
  limbThickness: z.number().min(0.7).max(1.5),
  eyes: idSchema,
  mouth: idSchema,
  hat: idSchema.nullable(),
  hatColor: color,
  shirt: idSchema.nullable(),
  shirtColor: color,
  ballColor: color,
  trailColor: color,
  ink: InkSchema.optional(),
});

export type Appearance = z.output<typeof AppearanceSchema>;

export const DEFAULT_APPEARANCE: Appearance = {
  v: 1,
  bodyColor: '#2b2d42',
  outlineColor: '#11121c',
  headShape: 'round',
  headScale: 1.0,
  limbThickness: 1.0,
  eyes: 'dot',
  mouth: 'smile',
  hat: null,
  hatColor: '#e63946',
  shirt: 'tee',
  shirtColor: '#457b9d',
  ballColor: '#ffffff',
  trailColor: '#ffd166',
};

export const DisplayNameSchema = z
  .string()
  .trim()
  .min(3, 'must be 3-16 characters')
  .max(16, 'must be 3-16 characters')
  .regex(/^[A-Za-z0-9_ ]+$/, 'may only contain letters, digits, underscore and space');
