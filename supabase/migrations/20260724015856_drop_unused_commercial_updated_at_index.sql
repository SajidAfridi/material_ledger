-- Batch 2 reads commercial records by their composite primary key or as a
-- small capability-gated set. Avoid a speculative secondary index until a
-- measured query needs ordering by updated_at.
drop index if exists public.commercial_records_updated_at_idx;
