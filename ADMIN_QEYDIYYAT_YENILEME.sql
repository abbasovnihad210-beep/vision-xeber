-- Vision Xəbər: qeydiyyatdan sonra könüllü hesabı
-- Mövcud Baş Admin/Admin hesablarına toxunmur.
CREATE OR REPLACE FUNCTION public.create_profile_on_signup()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 INSERT INTO public.profiles(id,display_name,role,status)
 VALUES(NEW.id,LEFT(COALESCE(NEW.raw_user_meta_data->>'name',''),120),
 CASE WHEN NEW.raw_user_meta_data->>'account_kind'='volunteer' THEN 'volunteer' ELSE 'pending' END,
 CASE WHEN NEW.raw_user_meta_data->>'account_kind'='volunteer' THEN 'active' ELSE 'pending' END)
 ON CONFLICT(id) DO NOTHING;
 RETURN NEW;
END;$$;
-- Trigger əvvəlki schema.sql faylında yaradılıb.
-- Əgər trigger yoxdursa, yaradırıq:
DROP TRIGGER IF EXISTS create_profile_after_signup ON auth.users;
CREATE TRIGGER create_profile_after_signup AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.create_profile_on_signup();
NOTIFY pgrst, 'reload schema';
