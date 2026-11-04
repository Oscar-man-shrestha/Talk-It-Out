-- 005_profiles.sql — public profile, work experience, education, and
-- uploaded profile images (avatar / cover). Additive only: no existing
-- table or column changes.

CREATE TABLE user_profiles (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  headline text NOT NULL DEFAULT '',
  bio text NOT NULL DEFAULT '',
  location text NOT NULL DEFAULT '',
  website text NOT NULL DEFAULT '',
  github_handle text NOT NULL DEFAULT '',
  twitter_handle text NOT NULL DEFAULT '',
  linkedin_url text NOT NULL DEFAULT '',
  skills text[] NOT NULL DEFAULT '{}',
  avatar_media_id uuid,
  cover_media_id uuid,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE user_experiences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL,
  company text NOT NULL,
  location text NOT NULL DEFAULT '',
  start_date date NOT NULL,
  end_date date,
  is_current boolean NOT NULL DEFAULT false,
  description text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT experience_dates CHECK (end_date IS NULL OR end_date >= start_date),
  CONSTRAINT experience_current_open CHECK (NOT is_current OR end_date IS NULL)
);

CREATE INDEX user_experiences_user_idx ON user_experiences (user_id);

CREATE TABLE user_educations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  school text NOT NULL,
  degree text NOT NULL DEFAULT '',
  field_of_study text NOT NULL DEFAULT '',
  start_year int CHECK (start_year BETWEEN 1900 AND 2200),
  end_year int CHECK (end_year BETWEEN 1900 AND 2200),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT education_years CHECK (
    start_year IS NULL OR end_year IS NULL OR end_year >= start_year
  )
);

CREATE INDEX user_educations_user_idx ON user_educations (user_id);

-- Uploaded images are stored in Postgres for v1 (no object-store
-- credentials exist yet). Only the latest avatar and cover per user are
-- kept; an upload replaces the previous row.
CREATE TABLE media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('avatar', 'cover')),
  content_type text NOT NULL
    CHECK (content_type IN ('image/png', 'image/jpeg', 'image/webp')),
  bytes bytea NOT NULL,
  byte_size int NOT NULL CHECK (byte_size > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX media_owner_kind_idx ON media (owner_id, kind);
