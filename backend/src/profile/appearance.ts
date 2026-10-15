import { z } from 'zod';

const color = z.string().regex(/^#[0-9a-fA-F]{6}$/, 'must be a #rrggbb color');
export const idSchema = z.string().regex(/^[a-z0-9_]{1,32}$/, 'must match ^[a-z0-9_]{1,32}$');

/** Appearance v1 (API.md §1.3). Unknown keys are rejected. */
export const AppearanceSchema = z.strictObject({
  v: z.literal(1),
  /** "stickman" (customisable) or a roster character id. Optional for older clients. */
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
