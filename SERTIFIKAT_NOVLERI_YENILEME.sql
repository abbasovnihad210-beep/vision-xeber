-- VISION XƏBƏR • SERTİFİKAT NÖVLƏRİ VƏ SƏRBƏST BAŞLIQ
-- ƏVVƏLKI certificates cədvəlini silmir və mövcud sertifikatları saxlayır.
ALTER TABLE public.certificates
  ADD COLUMN IF NOT EXISTS certificate_type TEXT NOT NULL DEFAULT 'Könüllülük',
  ADD COLUMN IF NOT EXISTS certificate_title TEXT NOT NULL DEFAULT 'SERTİFİKAT';

ALTER TABLE public.certificates
  DROP CONSTRAINT IF EXISTS certificates_type_length;
ALTER TABLE public.certificates
  ADD CONSTRAINT certificates_type_length
  CHECK (char_length(certificate_type) BETWEEN 2 AND 100);

ALTER TABLE public.certificates
  DROP CONSTRAINT IF EXISTS certificates_title_length;
ALTER TABLE public.certificates
  ADD CONSTRAINT certificates_title_length
  CHECK (char_length(certificate_title) BETWEEN 3 AND 180);

DROP FUNCTION IF EXISTS public.verify_vision_certificate(TEXT);
CREATE FUNCTION public.verify_vision_certificate(p_code TEXT)
RETURNS TABLE (
 code TEXT, recipient_name TEXT, program TEXT,
 description TEXT, issued_on DATE, status TEXT,
 certificate_type TEXT, certificate_title TEXT
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
 SELECT c.code,c.recipient_name,c.program,c.description,
 c.issued_on,c.status,c.certificate_type,c.certificate_title
 FROM public.certificates c
 WHERE c.code = trim(p_code) AND c.status = 'issued'
 LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.verify_vision_certificate(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_vision_certificate(TEXT) TO anon, authenticated;
NOTIFY pgrst, 'reload schema';
