-- Player reports from matches (API.md §1.8). One report per reporter, target and match.

CREATE TABLE player_reports (
  id           uuid        PRIMARY KEY,
  reporter_id  uuid        NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  target_id    uuid        NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  match_id     text        NOT NULL,
  reason       text        NOT NULL,
  note         text        NOT NULL DEFAULT '',
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (reporter_id, target_id, match_id)
);

CREATE INDEX player_reports_target_idx ON player_reports (target_id, created_at DESC);
