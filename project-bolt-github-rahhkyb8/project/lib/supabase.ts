'use client';

import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL as string;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY as string;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase env vars');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: { persistSession: false },
});

export const DEMO_USER_ID = '00000000-0000-0000-0000-000000000001';

export type Drama = {
  id: string;
  title: string;
  genre: string;
  tagline: string | null;
  cover_url: string;
  description: string;
  rank_badge: number | null;
};

export type Episode = {
  id: string;
  drama_id: string;
  episode_number: number;
  title: string;
  video_url: string;
  thumbnail_url: string;
  duration_sec: number;
  is_free: boolean;
};

export type AppUser = {
  id: string;
  email: string;
  coin_balance: number;
};

export type Transaction = {
  id: string;
  user_id: string;
  type: string;
  description: string | null;
  amount_php: number;
  coins_change: number;
  created_at: string;
};

export type UnlockedEpisode = {
  id: string;
  user_id: string;
  episode_id: string;
};

export type UnlockedSeries = {
  id: string;
  user_id: string;
  drama_id: string;
};

export type WatchProgress = {
  id: string;
  user_id: string;
  episode_id: string;
  position_sec: number;
  completed: boolean;
  updated_at: string;
};

export type CoinPack = {
  id: string;
  label: string;
  amount_php: number;
  coins: number;
  highlight?: boolean;
  tag?: string;
};

export const COIN_PACKS: CoinPack[] = [
  {
    id: 'single',
    label: 'Single Episode',
    amount_php: 15,
    coins: 20,
    tag: '1 episode',
  },
  {
    id: 'mini',
    label: 'Mini Pack',
    amount_php: 50,
    coins: 75,
    highlight: true,
    tag: '7 episodes',
  },
  {
    id: 'full',
    label: 'Full Series Unlock',
    amount_php: 150,
    coins: 250,
    tag: 'Episodes 11-40',
  },
];
