-- Cosmetic collection v1: owned items and pack openings (API.md §6).
-- Default items (catalog "default": true) are owned implicitly and never stored.

CREATE TABLE player_items (
  player_id    uuid        NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  item_id      text        NOT NULL,
  copies       integer     NOT NULL DEFAULT 1 CHECK (copies >= 1),
  acquired_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (player_id, item_id)
);

CREATE TABLE pack_openings (
  id           uuid        PRIMARY KEY,
  player_id    uuid        NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  pack_id      text        NOT NULL,
  cost         integer     NOT NULL,
  refund       integer     NOT NULL,
  items        jsonb       NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX pack_openings_player_idx ON pack_openings (player_id, created_at DESC);
