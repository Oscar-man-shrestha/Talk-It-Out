-- Why a message was not rephrased, and advisory moderation flags
-- (groups-pipeline-contract.md, API.md 72). Codes only, never text.

ALTER TABLE raw_messages
  ADD COLUMN pipeline_error_code text
    CHECK (pipeline_error_code IS NULL OR pipeline_error_code ~ '^[a-z_]{1,100}$'),
  ADD COLUMN moderation_flags text[] NOT NULL DEFAULT '{}'
    CHECK (moderation_flags <@ ARRAY['hate_speech', 'threat', 'abusive_language',
                                     'profanity', 'self_harm']::text[]);
