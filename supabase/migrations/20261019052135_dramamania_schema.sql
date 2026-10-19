/*
# DramaMania — core schema + seed data

## Overview
Single-tenant demo app (no sign-in). One shared demo user represents the viewer.
The frontend reads/writes as the anon role, so every policy lists anon + authenticated.

## New Tables
1. `dramas` — the 4 original series (title, genre, cover, description).
2. `episodes` — 40 episodes per drama (160 total). First 3 of every series are free.
3. `users` — single demo user holding `coin_balance`.
4. `transactions` — purchase / spend history for the demo user.
5. `unlocked_episodes` — episodes the user unlocked individually (by spending credits).
6. `unlocked_series` — series the user fully unlocked (eps 11-40).
7. `watch_progress` — per-episode playback position for "Continue Watching".

## Security
- RLS enabled on every table.
- All policies `TO anon, authenticated` with permissive predicates because this is an
  intentionally shared/single-tenant demo with no sign-in screen. No multi-user isolation.
- No auth.users FK — `users` is a plain data table with a fixed demo row.
*/

CREATE TABLE IF NOT EXISTS dramas (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title       text NOT NULL,
  genre       text NOT NULL,
  tagline     text,
  cover_url   text NOT NULL,
  description text NOT NULL,
  rank_badge  int,
  created_at  timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS episodes (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drama_id       uuid NOT NULL REFERENCES dramas(id) ON DELETE CASCADE,
  episode_number int  NOT NULL,
  title          text NOT NULL,
  video_url      text NOT NULL,
  thumbnail_url  text NOT NULL,
  duration_sec   int  NOT NULL DEFAULT 300,
  is_free        boolean NOT NULL DEFAULT false,
  created_at     timestamptz DEFAULT now(),
  UNIQUE (drama_id, episode_number)
);

CREATE TABLE IF NOT EXISTS users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         text NOT NULL,
  coin_balance  int  NOT NULL DEFAULT 0,
  created_at    timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS transactions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type         text NOT NULL,
  description  text,
  amount_php   numeric NOT NULL DEFAULT 0,
  coins_change int  NOT NULL DEFAULT 0,
  created_at   timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS unlocked_episodes (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  episode_id   uuid NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  created_at   timestamptz DEFAULT now(),
  UNIQUE (user_id, episode_id)
);

CREATE TABLE IF NOT EXISTS unlocked_series (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  drama_id     uuid NOT NULL REFERENCES dramas(id) ON DELETE CASCADE,
  created_at   timestamptz DEFAULT now(),
  UNIQUE (user_id, drama_id)
);

CREATE TABLE IF NOT EXISTS watch_progress (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  episode_id      uuid NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  position_sec    int  NOT NULL DEFAULT 0,
  completed       boolean NOT NULL DEFAULT false,
  updated_at      timestamptz DEFAULT now(),
  UNIQUE (user_id, episode_id)
);

CREATE INDEX IF NOT EXISTS idx_episodes_drama ON episodes(drama_id, episode_number);
CREATE INDEX IF NOT EXISTS idx_tx_user ON transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_progress_user ON watch_progress(user_id, updated_at DESC);

ALTER TABLE dramas ENABLE ROW LEVEL SECURITY;
ALTER TABLE episodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE unlocked_episodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE unlocked_series ENABLE ROW LEVEL SECURITY;
ALTER TABLE watch_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "dramas_read" ON dramas;
CREATE POLICY "dramas_read" ON dramas FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "episodes_read" ON episodes;
CREATE POLICY "episodes_read" ON episodes FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "users_read" ON users;
CREATE POLICY "users_read" ON users FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "users_write" ON users;
CREATE POLICY "users_write" ON users FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "users_update" ON users;
CREATE POLICY "users_update" ON users FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "tx_read" ON transactions;
CREATE POLICY "tx_read" ON transactions FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "tx_write" ON transactions;
CREATE POLICY "tx_write" ON transactions FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "ue_read" ON unlocked_episodes;
CREATE POLICY "ue_read" ON unlocked_episodes FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "ue_write" ON unlocked_episodes;
CREATE POLICY "ue_write" ON unlocked_episodes FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "ue_del" ON unlocked_episodes;
CREATE POLICY "ue_del" ON unlocked_episodes FOR DELETE TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "us_read" ON unlocked_series;
CREATE POLICY "us_read" ON unlocked_series FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "us_write" ON unlocked_series;
CREATE POLICY "us_write" ON unlocked_series FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "us_del" ON unlocked_series;
CREATE POLICY "us_del" ON unlocked_series FOR DELETE TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "wp_read" ON watch_progress;
CREATE POLICY "wp_read" ON watch_progress FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "wp_write" ON watch_progress;
CREATE POLICY "wp_write" ON watch_progress FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "wp_update" ON watch_progress;
CREATE POLICY "wp_update" ON watch_progress FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

INSERT INTO users (id, email, coin_balance)
VALUES ('00000000-0000-0000-0000-000000000001', 'guest@dramamania.app', 0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO dramas (id, title, genre, tagline, cover_url, description, rank_badge)
VALUES
  ('11111111-1111-1111-1111-111111111111',
   'The Billionaire''s Regret',
   'Romance',
   'He had everything. He lost her.',
   'https://images.pexels.com/photos/8272156/pexels-photo-8272156.jpeg?auto=compress&cs=tinysrgb&w=800&h=1200&fit=crop',
   'Self-made tycoon Adrian Cruz had the world at his feet — until the woman he quietly discarded returns as the lawyer assigned to dismantle his empire. A love story about pride, power, and the price of regret.',
   1),
  ('22222222-2222-2222-2222-222222222222',
   'Reborn: Power Reversal',
   'Power Reversal',
   'This time, he writes the rules.',
   'https://images.pexels.com/photos/18453038/pexels-photo-18453038.jpeg?auto=compress&cs=tinysrgb&w=800&h=1200&fit=crop',
   'Betrayed and left for dead, Marco wakes up ten years in the past with every memory of how his enemies destroyed him. Now he''s rewriting history — one calculated move at a time.',
   2),
  ('33333333-3333-3333-3333-333333333333',
   'Love Signal 2077',
   'Sci-Fi Romance',
   'Across timelines, one frequency remains.',
   'https://images.pexels.com/photos/8107910/pexels-photo-8107910.jpeg?auto=compress&cs=tinysrgb&w=800&h=1200&fit=crop',
   'In Neo Manila 2077, a rogue signal engineer picks up a transmission from a woman who died forty years ago. As they fall in love across fractured timelines, a corporation will do anything to silence the frequency.',
   3),
  ('44444444-4444-4444-4444-444444444444',
   'The Last Enchantress',
   'Fantasy',
   'Magic remembers what the world forgot.',
   'https://images.pexels.com/photos/29384699/pexels-photo-29384699.jpeg?auto=compress&cs=tinysrgb&w=800&h=1200&fit=crop',
   'When the last enchantress awakens from a thousand-year seal, she finds a kingdom that has outlawed magic and a young prince who is fated to kill her — or save her. An epic of spells, thrones, and forbidden love.',
   4)
ON CONFLICT (id) DO NOTHING;

DO $$
DECLARE
  d_id uuid;
  n int;
  thumbs text[];
  vids  text[];
  subs  text[];
  thumb text;
  vid   text;
  ep_title text;
  arr_len int;
  sub_len int;
  d_row RECORD;
BEGIN
  vids := ARRAY[
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4'
  ];

  FOR d_row IN SELECT id FROM dramas LOOP
    d_id := d_row.id;

    IF d_id = '11111111-1111-1111-1111-111111111111'::uuid THEN
      thumbs := ARRAY[
        'https://images.pexels.com/photos/8272156/pexels-photo-8272156.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/4390588/pexels-photo-4390588.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/4099034/pexels-photo-4099034.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/7991397/pexels-photo-7991397.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/35964821/pexels-photo-35964821.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/9198191/pexels-photo-9198191.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/5778670/pexels-photo-5778670.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/7299450/pexels-photo-7299450.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop'
      ];
      subs := ARRAY['The Contract','First Glance','The Gala','Cold Feet','The Proposal','Her Return','The Boardroom','Rain in BGC','The Verdict','The Regret'];
    ELSIF d_id = '22222222-2222-2222-2222-222222222222'::uuid THEN
      thumbs := ARRAY[
        'https://images.pexels.com/photos/18453038/pexels-photo-18453038.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/13307582/pexels-photo-13307582.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/6418742/pexels-photo-6418742.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/37662423/pexels-photo-37662423.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/33290985/pexels-photo-33290985.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/30033734/pexels-photo-30033734.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/13808576/pexels-photo-13808576.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/33484151/pexels-photo-33484151.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop'
      ];
      subs := ARRAY['The Fall','Awakening','Old Enemies','The Inside Man','Countdown','The Takeover','Blood Debt','Second Chance','The Throne','Checkmate'];
    ELSIF d_id = '33333333-3333-3333-3333-333333333333'::uuid THEN
      thumbs := ARRAY[
        'https://images.pexels.com/photos/8107910/pexels-photo-8107910.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/7661394/pexels-photo-7661394.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/8108594/pexels-photo-8108594.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/8108282/pexels-photo-8108282.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/4904556/pexels-photo-4904556.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/7661399/pexels-photo-7661399.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop'
      ];
      subs := ARRAY['Signal Lost','The Frequency','Ghost in the Wire','Timeline 7','The Corporation','Her Voice','Blackout','The Bridge','2087','One Last Transmission'];
    ELSIF d_id = '44444444-4444-4444-4444-444444444444'::uuid THEN
      thumbs := ARRAY[
        'https://images.pexels.com/photos/29384699/pexels-photo-29384699.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/35850361/pexels-photo-35850361.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/14426830/pexels-photo-14426830.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/29384675/pexels-photo-29384675.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/15022114/pexels-photo-15022114.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop',
        'https://images.pexels.com/photos/38851586/pexels-photo-38851586.jpeg?auto=compress&cs=tinysrgb&w=600&h=900&fit=crop'
      ];
      subs := ARRAY['The Seal Breaks','The Prince','Forbidden Magic','The Council','Awakening','The Hunt','Throne of Ash','The Pact','Last Spell','Dawn of Magic'];
    END IF;

    arr_len := array_length(thumbs,1);
    sub_len := array_length(subs,1);

    FOR n IN 1..40 LOOP
      thumb := thumbs[ ((n - 1) % arr_len) + 1 ];
      vid   := vids[ ((n - 1) % 10) + 1 ];
      ep_title := subs[ ((n - 1) % sub_len) + 1 ];

      INSERT INTO episodes (drama_id, episode_number, title, video_url, thumbnail_url, duration_sec, is_free)
      VALUES (d_id, n, ep_title, vid, thumb, 300, n <= 3)
      ON CONFLICT (drama_id, episode_number) DO NOTHING;
    END LOOP;
  END LOOP;
END $$;
