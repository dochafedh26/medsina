-- Migration: App Release Versions for In-App OTA Updates
-- Description: Stores platform-specific release metadata, changelogs, download URLs, and minimum supported versions.

CREATE TABLE IF NOT EXISTS public.app_releases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL CHECK (platform IN ('android', 'windows', 'web', 'all')),
    version_name TEXT NOT NULL,           -- e.g. '1.1.0'
    build_number INT NOT NULL,            -- e.g. 2
    release_notes TEXT NOT NULL,          -- Markdown changelog
    download_url TEXT NOT NULL,           -- Direct APK download URL or installer link
    is_mandatory BOOLEAN NOT NULL DEFAULT FALSE, -- Force update if current build < build_number
    min_supported_build INT NOT NULL DEFAULT 1,
    sha256_hash TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    published_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Index for instant lookup of latest active version per platform
CREATE INDEX IF NOT EXISTS idx_app_releases_platform_active 
ON public.app_releases (platform, is_active, build_number DESC);

-- Enable RLS
ALTER TABLE public.app_releases ENABLE ROW LEVEL SECURITY;

-- Everyone can read active releases
CREATE POLICY "Public read active releases" 
ON public.app_releases
FOR SELECT 
USING (is_active = TRUE);

-- Only authenticated admins or service role can insert/update/delete releases
CREATE POLICY "Admin write app releases" 
ON public.app_releases
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
);

-- Seed initial production release v1.0.0
INSERT INTO public.app_releases (
    platform,
    version_name,
    build_number,
    release_notes,
    download_url,
    is_mandatory,
    min_supported_build,
    sha256_hash,
    is_active
) VALUES 
(
    'android',
    '1.0.0',
    1,
    '### Nouveautés de Medsina v1.0.0 ✨\n- 📚 47 Modules & 1 205 Cours Officiels de Résidanat.\n- 📋 Fiches Synthétiques & Pièges de Concours QCM.\n- 🩺 Conduites à Tenir Cliniques (CAT) & Urgences Hospitalières.\n- 💊 Guide Thérapeutique d''Urgence & DCI Algérie.\n- 🔬 Normes & Interprétations Biologiques.\n- ⚡ Mises à jour OTA automatiques intégrées.',
    'https://qzfssrhhuorljftpdvjm.supabase.co/storage/v1/object/public/releases/Medsina_v1.0.0_Android_Release.apk',
    false,
    1,
    'EF85D507743E85984CACA687E989145571212073FA1989DB2414D30493A9BD05',
    true
),
(
    'windows',
    '1.0.0',
    1,
    '### Nouveautés de Medsina v1.0.0 pour Windows 🖥️\n- Application native haute performance 64-bit.\n- Lecteur PDF intégré avec recherche ultra-rapide.\n- Toutes les spécialités médicales disponibles hors-ligne.',
    'https://qzfssrhhuorljftpdvjm.supabase.co/storage/v1/object/public/releases/Medsina_v1.0.0_Windows_x64.zip',
    false,
    1,
    'A80F66127469FD3F61E34C62A9BA161048A83206A3A40ED4B3CEE175BDF1B05A',
    true
)
ON CONFLICT DO NOTHING;
