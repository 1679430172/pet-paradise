ALTER TABLE public.announcements
  ADD COLUMN IF NOT EXISTS target_class_ids UUID[] CHECK (cardinality(target_class_ids) > 0),
  ADD COLUMN IF NOT EXISTS teachers_only BOOLEAN NOT NULL DEFAULT false;
