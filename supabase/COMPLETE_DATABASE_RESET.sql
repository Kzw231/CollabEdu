-- =============================================================================
-- COMPLETE DATABASE RESET — CollabEdu / assignment (Supabase PostgreSQL)
-- =============================================================================
-- WARNING: Destructive. Drops public tables, triggers, and related functions for
-- this app, then recreates schema + RLS + invite_lookup_member + auth trigger.
--
-- Does NOT delete rows in auth.users. After running, existing login accounts may
-- lack a matching public.members row; fix via Supabase Auth (delete users) or
-- insert members manually, or run BACKFILL_MEMBERS_FROM_AUTH.sql once. New signups
-- get a members row from the trigger.
--
-- Storage: create bucket "project_files" in Supabase Storage (private) if you
-- use file uploads — SQL cannot create buckets.
--
-- Run the whole script in the Supabase SQL Editor as a single transaction is
-- optional; if a statement fails, fix and re-run from that point or run fresh.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Tear down (order: trigger → functions that reference tables → tables)
-- -----------------------------------------------------------------------------

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.generate_member_id() CASCADE;
DROP FUNCTION IF EXISTS public.invite_lookup_member(text, text) CASCADE;

DROP TABLE IF EXISTS public.files CASCADE;
DROP TABLE IF EXISTS public.tasks CASCADE;
DROP TABLE IF EXISTS public.project_members CASCADE;
DROP TABLE IF EXISTS public.projects CASCADE;
DROP TABLE IF EXISTS public.members CASCADE;

DROP SEQUENCE IF EXISTS public.members_id_seq CASCADE;

-- -----------------------------------------------------------------------------
-- 2) Members id generator (M0001, M0002, …)
-- -----------------------------------------------------------------------------

CREATE SEQUENCE public.members_id_seq;

CREATE OR REPLACE FUNCTION public.generate_member_id()
RETURNS text
LANGUAGE sql
SET search_path = public
AS $$
  SELECT 'M' || lpad(nextval('public.members_id_seq')::text, 4, '0');
$$;

-- -----------------------------------------------------------------------------
-- 3) Tables (IDs are text / UUID strings from the Flutter app)
-- -----------------------------------------------------------------------------

CREATE TABLE public.members (
  id text PRIMARY KEY,
  name text NOT NULL DEFAULT '',
  email text NOT NULL,
  bio text,
  avatar_url text,
  auth_uid uuid NOT NULL UNIQUE REFERENCES auth.users (id) ON DELETE CASCADE,
  CONSTRAINT members_email_unique UNIQUE (email)
);

CREATE TABLE public.projects (
  id text PRIMARY KEY,
  name text NOT NULL,
  description text NOT NULL DEFAULT '',
  deadline timestamptz NOT NULL,
  created_by text NOT NULL REFERENCES public.members (id),
  created_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active'
);

CREATE TABLE public.project_members (
  project_id text NOT NULL REFERENCES public.projects (id) ON DELETE CASCADE,
  member_id text NOT NULL REFERENCES public.members (id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member',
  PRIMARY KEY (project_id, member_id)
);

CREATE TABLE public.tasks (
  id text PRIMARY KEY,
  project_id text NOT NULL REFERENCES public.projects (id) ON DELETE CASCADE,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  assigned_to text NOT NULL DEFAULT '',
  created_by text NOT NULL DEFAULT '',
  start_date timestamptz NOT NULL,
  due_date timestamptz NOT NULL,
  actual_start_date timestamptz,
  progress_percent int NOT NULL DEFAULT 0,
  estimated_hours int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending',
  completed_at timestamptz,
  priority int NOT NULL DEFAULT 1,
  tags text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  parent_task_id text REFERENCES public.tasks (id) ON DELETE SET NULL
);

CREATE TABLE public.files (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id text NOT NULL REFERENCES public.projects (id) ON DELETE CASCADE,
  file_name text NOT NULL,
  storage_path text NOT NULL,
  file_size bigint NOT NULL,
  mime_type text NOT NULL,
  uploaded_by text NOT NULL REFERENCES public.members (id),
  file_type text NOT NULL,
  uploaded_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX project_members_member_id_idx ON public.project_members (member_id);
CREATE INDEX tasks_project_id_idx ON public.tasks (project_id);
CREATE INDEX files_project_id_idx ON public.files (project_id);

-- -----------------------------------------------------------------------------
-- 4) New Supabase Auth user → public.members row
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.members (id, name, email, auth_uid)
  VALUES (
    public.generate_member_id(),
    COALESCE(NEW.raw_user_meta_data ->> 'name', ''),
    COALESCE(NEW.email, ''),
    NEW.id
  );
  RETURN NEW;
END;
$$;

-- On PostgreSQL 14+ use EXECUTE FUNCTION; on older versions use EXECUTE PROCEDURE.
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- -----------------------------------------------------------------------------
-- 5) RPC: invite / lookup by email or member id (no v_id scalars — avoids 42P01)
-- Same logic as supabase/invite_lookup_member_rpc.sql
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.invite_lookup_member(
  p_email text DEFAULT NULL,
  p_id text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (
    SELECT json_build_object(
      'id', sub.id_text,
      'name', sub.member_name,
      'email', sub.member_email
    )
    FROM (
      SELECT
        m.id::text AS id_text,
        m.name AS member_name,
        m.email AS member_email
      FROM public.members AS m
      WHERE
        CASE
          WHEN p_id IS NOT NULL AND btrim(p_id) <> '' THEN m.id::text = btrim(p_id)
          WHEN p_email IS NOT NULL AND btrim(p_email) <> '' THEN lower(btrim(m.email)) = lower(btrim(p_email))
          ELSE false
        END
      LIMIT 1
    ) AS sub
  );
END;
$$;

REVOKE ALL ON FUNCTION public.invite_lookup_member(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.invite_lookup_member(text, text) TO authenticated;

-- -----------------------------------------------------------------------------
-- 6) Row Level Security
-- -----------------------------------------------------------------------------

ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.files ENABLE ROW LEVEL SECURITY;

-- members: directory lists everyone; users may update only their own row.
CREATE POLICY members_select_authenticated
  ON public.members
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY members_update_own
  ON public.members
  FOR UPDATE
  TO authenticated
  USING (auth_uid = auth.uid())
  WITH CHECK (auth_uid = auth.uid());

-- projects: see projects you belong to; create with yourself as created_by;
-- update/delete if you are a project member (matches app: any member may delete).
CREATE POLICY projects_select_if_member
  ON public.projects
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.project_members pm
      WHERE pm.project_id = projects.id
        AND pm.member_id = (SELECT m.id FROM public.members m WHERE m.auth_uid = auth.uid() LIMIT 1)
    )
  );

CREATE POLICY projects_insert
  ON public.projects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    created_by = (SELECT m.id FROM public.members m WHERE m.auth_uid = auth.uid() LIMIT 1)
  );

CREATE POLICY projects_update_if_member
  ON public.projects
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.project_members pm
      WHERE pm.project_id = projects.id
        AND pm.member_id = (SELECT m2.id FROM public.members m2 WHERE m2.auth_uid = auth.uid() LIMIT 1)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.project_members pm
      WHERE pm.project_id = projects.id
        AND pm.member_id = (SELECT m.id FROM public.members m WHERE m.auth_uid = auth.uid() LIMIT 1)
    )
  );

CREATE POLICY projects_delete_if_member
  ON public.projects
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.project_members pm
      WHERE pm.project_id = projects.id
        AND pm.member_id = (SELECT m.id FROM public.members m WHERE m.auth_uid = auth.uid() LIMIT 1)
    )
  );

-- project_members: permissive SELECT avoids recursive policy graphs; inserts
-- allowed for project creator (first members) or existing members (invites).
CREATE POLICY project_members_select_authenticated
  ON public.project_members
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY project_members_insert
  ON public.project_members
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.projects p
      WHERE p.id = project_members.project_id
        AND p.created_by = (SELECT m.id FROM public.members m WHERE m.auth_uid = auth.uid() LIMIT 1)
    )
    OR EXISTS (
      SELECT 1
      FROM public.project_members pm
      WHERE pm.project_id = project_members.project_id
        AND pm.member_id = (SELECT m.id FROM public.members m WHERE m.auth_uid = auth.uid() LIMIT 1)
    )
  );

CREATE POLICY project_members_delete
  ON public.project_members
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.projects p
      WHERE p.id = project_members.project_id
        AND p.created_by = (SELECT m.id FROM public.members m WHERE m.auth_uid = auth.uid() LIMIT 1)
    )
    OR EXISTS (
      SELECT 1
      FROM public.project_members pm
      WHERE pm.project_id = project_members.project_id
        AND pm.member_id = (SELECT m.id FROM public.members m WHERE m.auth_uid = auth.uid() LIMIT 1)
    )
  );

-- tasks & files: must be a member of the parent project.
CREATE POLICY tasks_all_if_project_member
  ON public.tasks
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.project_members pm
      WHERE pm.project_id = tasks.project_id
        AND pm.member_id = (SELECT m.id FROM public.members m WHERE m.auth_uid = auth.uid() LIMIT 1)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.project_members pm
      WHERE pm.project_id = tasks.project_id
        AND pm.member_id = (SELECT m.id FROM public.members m WHERE m.auth_uid = auth.uid() LIMIT 1)
    )
  );

CREATE POLICY files_all_if_project_member
  ON public.files
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.project_members pm
      WHERE pm.project_id = files.project_id
        AND pm.member_id = (SELECT m.id FROM public.members m WHERE m.auth_uid = auth.uid() LIMIT 1)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.project_members pm
      WHERE pm.project_id = files.project_id
        AND pm.member_id = (SELECT m.id FROM public.members m WHERE m.auth_uid = auth.uid() LIMIT 1)
    )
  );

-- -----------------------------------------------------------------------------
-- Done. Optional: verify with:
--   SELECT routine_name FROM information_schema.routines
--   WHERE routine_schema = 'public' AND routine_name IN ('invite_lookup_member', 'handle_new_user');
-- =============================================================================
