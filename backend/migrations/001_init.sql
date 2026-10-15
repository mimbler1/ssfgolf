-- Initial schema for Fairway Frenzy backend v1.
-- Tables are created unqualified so they land in the connection's search_path
-- (tests run each file in its own schema).

CREATE TABLE players (
  id                   uuid PRIMARY KEY,
  display_name         text        NOT NULL,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  appearance           jsonb       NOT NULL,
  xp                   integer     NOT NULL DEFAULT 0 CHECK (xp >= 0),
  trophies             integer     NOT NULL DEFAULT 0 CHECK (trophies >= 0),
  highest_trophies     integer     NOT NULL DEFAULT 0 CHECK (highest_trophies >= 0),
  highest_trophies_at  timestamptz NOT NULL DEFAULT now(),
  coins                integer     NOT NULL DEFAULT 0 CHECK (coins >= 0),
  stat_matches         integer     NOT NULL DEFAULT 0,
  stat_wins            integer     NOT NULL DEFAULT 0,
  stat_holes_played    integer     NOT NULL DEFAULT 0,
  stat_hole_wins       integer     NOT NULL DEFAULT 0,
  stat_shots           integer     NOT NULL DEFAULT 0,
  stat_abilities_used  integer     NOT NULL DEFAULT 0,
  ability_usage        jsonb       NOT NULL DEFAULT '{}'::jsonb,
  current_win_streak   integer     NOT NULL DEFAULT 0,
  longest_win_streak   integer     NOT NULL DEFAULT 0
);

CREATE INDEX players_leaderboard_idx
  ON players (trophies DESC, highest_trophies_at ASC, id ASC);

CREATE TABLE device_credentials (
  device_id    uuid PRIMARY KEY,
  player_id    uuid        NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  secret_hash  text        NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  last_login_at timestamptz
);

CREATE INDEX device_credentials_player_idx ON device_credentials (player_id);

CREATE TABLE sessions (
  id          uuid PRIMARY KEY,
  player_id   uuid        NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  token_hash  text        NOT NULL UNIQUE,
  created_at  timestamptz NOT NULL,
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz
);

CREATE INDEX sessions_player_idx ON sessions (player_id);

CREATE TABLE matches (
  id             uuid PRIMARY KEY,
  mode           text        NOT NULL CHECK (mode IN ('quick', 'private')),
  ranked         boolean     NOT NULL,
  course_id      text        NOT NULL,
  target_points  integer     NOT NULL,
  room_code      text,
  server_id      uuid,
  server_host    text,
  server_port    integer,
  status         text        NOT NULL CHECK (status IN ('assigned', 'started', 'completed', 'aborted', 'cancelled', 'expired')),
  assignment     jsonb       NOT NULL,
  created_at     timestamptz NOT NULL,
  started_at     timestamptz,
  ended_at       timestamptz,
  ended_reason   text CHECK (ended_reason IN ('completed', 'aborted')),
  cancel_reason  text,
  result         jsonb
);

CREATE INDEX matches_status_idx ON matches (status);

CREATE TABLE match_players (
  match_id        uuid    NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  player_id       uuid    NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  slot            integer NOT NULL,
  display_name    text    NOT NULL,
  placement       integer NOT NULL,
  points          integer NOT NULL,
  holes_won       integer NOT NULL,
  holes_played    integer NOT NULL,
  shots           integer NOT NULL,
  abilities_used  jsonb   NOT NULL DEFAULT '{}'::jsonb,
  disconnected    boolean NOT NULL,
  trophy_delta    integer NOT NULL,
  trophies_after  integer NOT NULL,
  xp_gained       integer NOT NULL,
  coins_gained    integer NOT NULL,
  level_before    integer NOT NULL,
  level_after     integer NOT NULL,
  ended_at        timestamptz NOT NULL,
  PRIMARY KEY (match_id, player_id)
);

CREATE INDEX match_players_player_idx ON match_players (player_id, ended_at DESC);
