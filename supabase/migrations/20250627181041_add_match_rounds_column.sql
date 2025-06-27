-- Add number_of_rounds column to matches table
ALTER TABLE public.matches
ADD COLUMN number_of_rounds integer NOT NULL DEFAULT 7;
