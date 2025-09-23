here’s a concrete add-on plan that anchors to Postiz-App’s current features, UI, and extension points, and then shows exactly how we bolt your API-first AI Content Studio onto it.

Where Postiz stands today (what we’re building on)

What Postiz already does (core):

Multi-platform social scheduling (Instagram, LinkedIn, X, Reddit, Pinterest, YouTube, TikTok, Bluesky, Mastodon, Discord, etc.). It’s open-source/self-hostable with a hosted option. 
GitHub
+1

Calendar / composer UX to create and schedule posts, plus basic analytics and team support. 
Reddit
+1

A Public API for headless operations (file upload + post creation), authenticated with a workspace API key; hosted base URL or your self-hosted backend under /public/v1. 
Postiz Documentation
+1

Providers configuration: Postiz documents how providers are added/configured, and expects env-driven provider settings. (This is for social networks, but their pattern guides our add-ins.) 
Postiz Documentation
+1

Deployment expectations: backend reachable on port 3000 in docker-compose topologies. 
GitHub

Implication: We reuse Postiz auth, teams, calendar/composer, analytics, and the Public API, and augment with AI discovery/generation/stitching that outputs assets back into the existing post creation & scheduling flow.

UX: How we add to the existing UI
Sidebar

Add a new top-level menu AI Studio with five sub-pages:

Inbox – news sources (Google Alerts via RSS, generic RSS/Atom, Reddit). Shows items, “Summarize”, “Generate ideas”.

Pipelines – visual & JSON editor for multi-step API pipelines (Research → Text → Image/Video Clip → TTS → Stitch → Captions → Publish).

Timeline – lightweight editor (preview + track list) for stitching provider-generated clips/images/audio into a finished video.

Assets – media library filtered to AI outputs (thumbnails, duration, tags), with “Add to Timeline” / “Send to Composer”.

AI Settings – Provider Registry for external APIs (Perplexity, GPT-5, VEO-3, SeaDance, 11Labs, Whisper-as-API, generic Replicate/fal.ai), plus budgets/quotas.

Nothing in the existing Composer/Calendar changes functionally; we just add actions like “Send to Composer” (pre-fill caption + attach media) and “Schedule” (deep-link into Postiz’s normal scheduler). This keeps user muscle memory intact. Postiz already markets AI features and scheduling; we’re slotting into a place users expect to find them. 
Postiz Documentation

Frontend integration (Next.js)

Routes (e.g., /ai-studio/inbox, /ai-studio/pipelines, …).

Shared UI tokens (brand profiles, workspace selector, team roles) follow Postiz conventions.

Composer handoff: when the user clicks Send to Composer, we navigate to the existing Postiz composer with payload (text, hashtags, attached media) pre-staged. If needed (depending on internal APIs), we stage media first via the Public API upload then open the composer with the file IDs. 
Postiz Documentation

Calendar handoff: Schedule flows remain Postiz-native so queueing, approvals, and analytics remain unified.

Backend integration (NestJS)

We add three backend modules that live alongside Postiz’s backend:

Provider Registry Service

CRUD for external AI providers (not social posting providers) with encrypted secrets.

Mirrors Postiz’s “providers” idea, but for capabilities: Research, Text, Image, VideoClip, TTS, Captions.

Admin UI sits under AI Settings.

Reference Postiz “create provider” docs for DTO/validation patterns (we’re not touching social providers; just reusing the pattern). 
Postiz Documentation

Pipeline Engine

Executes a pipeline spec (JSON) as jobs in BullMQ, uses webhooks first (providers that support callbacks), then polling as fallback.

Produces Assets (image/video/audio/captions) by storing provider returns into S3/R2 and registering them in our Assets table.

Render & Stitch Service

CPU-safe Remotion + ffmpeg composition.

Takes clips/audio/overlays and renders final MP4, thumbnails, and optional .srt burn-in.

Outputs are added to Assets and visible on Assets & Timeline pages.

These modules do not replace Postiz’s social providers. They produce media and text that feed into existing publishing (either via the UI or Public API). Providers for AI live in our registry; providers for social posting remain in Postiz’s existing provider system & env config. 
Postiz Documentation

Publishing: how our outputs reach Postiz posts

Two ways (both supported by Postiz today):

UI path: “Send to Composer” → user edits → schedule normally.

Headless path: use Postiz Public API to upload files then create posts with those file IDs and the caption we generate. Works the same whether hosted or self-hosted (auth via workspace API key; /public/v1). 
Postiz Documentation
+1

This means approvals, repeats, webhooks, and analytics continue to behave like any Postiz post—no custom infra needed. (Postiz is often deployed with backend on port 3000; we follow that convention so the public API URL remains predictable.) 
GitHub

“Add, don’t fork” philosophy

No changes to Postiz’s social network providers or auth.

No bypassing the composer/calendar.

We add a vertical (AI Studio) that produces Postiz-native post payloads & media.

This keeps upgrades from upstream Postiz smoother (we’re not fighting their roadmap) and lets your AI Studio remain a module you can maintain independently.

Concretely, what your dev will implement first

AI Settings → Provider Registry

UI forms for: Perplexity, GPT-5, VEO-3 (voiced video), Sea Dance, 11Labs, Whisper-as-API, and a generic HTTP provider (Replicate/fal.ai).

Test connection buttons; save encrypted secrets; choose per-capability priority order (e.g., VideoClip: [VEO3, SeaDance, Replicate-model-X]).

Use Postiz’s provider docs as a reference for settings DTO patterns and validation style. 
Postiz Documentation

Inbox (Content discovery)

Add Google Alerts (RSS URL), generic RSS/Atom, Reddit subs.

Store items; show list; Summarize via your configured Research + Text providers. (Postiz docs already show an “AI” story in their intro; we’re plugging into that mental model.) 
Postiz Documentation

Pipelines

Visual builder + JSON view.

Ship the starter template “News-to-Story-Video”:
Research → Script (Text) → Scene fan-out to (VideoClip + TTS) → Stitch → Captions → Publish.

Timeline + Stitch

Drag generated clips/audio/overlays to tracks; Render (Remotion/ffmpeg).

Result saved to Assets; Send to Composer or Schedule via Public API.

Composer handoff

Implement a function that:
(a) uploads media via Public API; (b) opens composer prefilled; or (headless) (c) creates scheduled posts via Public API. 
Postiz Documentation

Why this aligns with Postiz’s architecture & docs

Providers are env-driven & documented—we reuse that mental model for an AI Provider Registry UI + backend config (our own namespace). 
Postiz Documentation

Public API exists for uploads & posts—we rely on it for clean, upgrade-safe integration. 
Postiz Documentation

Self-host friendly and Docker-Compose oriented—our services sit next to backend/frontend/redis/postgres, respecting the backend’s port 3000 expectation. 
Postiz Documentation
+1

Postiz scope (schedule/analytics/teams) stays authoritative; our AI Studio feeds it, not replaces it. 
Postiz Documentation

Acceptance checks specific to Postiz integration

AC-1: From Inbox, select an RSS item → “Summarize” (Perplexity) → “Generate ideas” (GPT-5) → “Send to Composer” opens the existing Postiz composer with prefilled text + uploaded image asset via Public API. 
Postiz Documentation

AC-2: From Pipelines, run “News-to-Story-Video” → clips generated by VEO-3, fallback to Sea Dance when VEO-3 intentionally fails (provider order honored).

AC-3: From Timeline, stitch 6 clips + VO, render MP4 on CPU; asset appears in Assets and can be attached to a post in the composer.

AC-4: Publish via Public API into two platforms; posts appear on Postiz calendar/analytics like any other post. 
Postiz Documentation

AC-5: Upgrade upstream Postiz to a newer tag; AI Studio remains functional (no social provider changes required).

PRD — Postiz Add ON “AI Content Studio” (API-First, Pluggable Providers)
0) Goals (revised)
•	No heavy models on our server. All image/video/voice generation happens via third-party APIs.
•	Pluggable provider registry. Per-workspace configuration of multiple providers per capability (Text, Research, Image, VideoClip, TTS, Captions).
•	Composable pipelines. A visual & JSON pipeline builder (DAG/sequence) to stitch steps (research → copy → images → clips → TTS → captions → stitch → schedule).
•	Webhook-first orchestration. Prefer provider webhooks; fall back to polling.
•	Brand + compliance. Enforce brand voice/style; capture citations; add safety checks.
________________________________________
1) High-Level Architecture
Existing Postiz services (reuse): Frontend (Next.js), Backend (NestJS), Postgres, Redis/BullMQ, Auth, Providers for social posting, Storage (S3/R2), Analytics.
New modules:
•	Provider Registry Service — CRUD for external API configs (keys, base URLs, model choices), capability tagging (e.g., capability: "VideoClip").
•	Pipeline Engine — Interprets a pipeline spec (JSON/YAML), enqueues steps, manages dependencies, handles webhooks/polling, retries, idempotency.
•	AI Orchestrator — Thin adapters calling external providers; normalizes request/response; streams status back to Pipeline Engine.
•	Render & Stitch Service — Uses ffmpeg + Remotion renderer only for editing/combining clips/assets we get back from providers (CPU-safe).
•	Content Discovery — RSS/Google Alerts/Reddit ingestion + summarize/angle generation (all text LLM calls via providers).
•	Cost & Quota Manager — Tracks spend/usage per workspace/provider; enforces budgets/alerts.
•	Observability — Step logs, timelines, and provider call traces for each run.
________________________________________
2) Capabilities & Provider Types
We support a capability matrix; each provider declares what it can do:
•	Research: web-aware Q&A/summaries (e.g., Perplexity).
•	Text: copy/scripts/outlines (GPT-5 or equivalent).
•	Image: text→image / image→image (any image gen API).
•	VideoClip: short text→video / image→video (e.g., VEO-3 fast, Sea Dance, Open-source via hosted APIs, fal/Replicate endpoints).
•	TTS/Voiceover: voice synthesis for narration (11Labs/Bark-as-a-service).
•	Captions: speech→text (Whisper-as-API or provider of your choice).
•	Stock (optional): stock footage/image search APIs.
Each capability is addressed via a provider adapter implementing a common interface (Strategy pattern).
________________________________________
3) Data Model (Prisma sketch)
model ProviderConfig {
  id            String   @id @default(cuid())
  workspaceId   String   @index
  name          String
  providerType  ProviderType   // OPENAI, PERPLEXITY, VEO3, SEADANCE, REPLICATE, ELEVENLABS, CUSTOM
  capabilities  Capability[]   // ["Text","VideoClip","Image","TTS","Captions","Research"]
  baseUrl       String?
  apiKeyRef     String         // reference to encrypted secret
  defaultParams Json?
  isEnabled     Boolean  @default(true)
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
}

model PipelineTemplate {
  id            String   @id @default(cuid())
  workspaceId   String   @index
  name          String
  description   String?
  specJson      Json     // pipeline DAG/spec (see below)
  version       Int      @default(1)
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
}

model PipelineRun {
  id            String   @id @default(cuid())
  workspaceId   String   @index
  templateId    String   @index
  inputJson     Json
  status        RunStatus // QUEUED, RUNNING, DONE, FAILED, PARTIAL
  startedAt     DateTime?
  finishedAt    DateTime?
  costCents     Int       @default(0)
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt
}

model StepRun {
  id            String   @id @default(cuid())
  pipelineRunId String   @index
  stepKey       String   // matches spec node key
  providerId    String?
  status        StepStatus // QUEUED, RUNNING, WAITING_WEBHOOK, DONE, FAILED, CANCELED
  requestJson   Json?
  responseJson  Json?
  outputAssetId String?
  error         String?
  startedAt     DateTime?
  finishedAt    DateTime?
  retries       Int       @default(0)
}

model Asset {
  id            String   @id @default(cuid())
  workspaceId   String   @index
  type          AssetType // IMAGE, VIDEO, AUDIO, CAPTION, JSON
  url           String    // S3/R2 URL
  width         Int?
  height        Int?
  durationMs    Int?
  metadata      Json?
  createdAt     DateTime  @default(now())
}

model BrandProfile {
  id            String   @id @default(cuid())
  workspaceId   String   @index
  name          String
  tone          Json      // persona rules, banned phrases, CTA library
  style         Json      // colors, fonts, logo URLs
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt
}
Secrets are stored via an internal Secrets Vault table or KMS; apiKeyRef points to encrypted data; decrypt only at call time.
________________________________________
4) Pipeline Spec (JSON)
A pipeline is a sequence/DAG of steps; each step declares:
•	type: Research|Text|Image|VideoClip|TTS|Captions|Stitch|Publish
•	providerPolicy: which provider(s) to try, in order (with param overrides)
•	input: templated data referencing prior step outputs ({{steps.research.brief}})
•	constraints: cost/time caps, max retries
•	outputs: expected schema (asset, json)
Example (story video from article):
{
  "name": "News-to-Story-Video",
  "steps": [
    {
      "key": "ingest",
      "type": "Research",
      "providerPolicy": ["PERPLEXITY_PRIMARY", "GPT5_WEB_FALLBACK"],
      "input": { "url": "{{input.url}}", "keywords": "{{input.keywords}}" },
      "outputs": { "brief": "json.summary", "key_points": "json.key_points" }
    },
    {
      "key": "script",
      "type": "Text",
      "providerPolicy": ["GPT5_PRIMARY"],
      "input": {
        "task": "Write 6 scenes with VO and on-screen text",
        "brief": "{{steps.ingest.brief}}",
        "brand": "{{input.brandProfile}}"
      },
      "outputs": { "scenes": "json.scenes" }
    },
    {
      "key": "clips",
      "type": "VideoClip",
      "parallel": true,
      "fanoutFrom": "script.scenes",
      "providerPolicy": ["VEO3_FAST", "SEADANCE"],
      "input": {
        "scene": "{{fanout.item}}",
        "aspect": "{{input.aspect}}",
        "durationSec": 10
      },
      "outputs": { "clip": "asset.video" }
    },
    {
      "key": "tts",
      "type": "TTS",
      "parallel": true,
      "fanoutFrom": "script.scenes",
      "providerPolicy": ["ELEVENLABS_EN_US_1"],
      "input": {
        "text": "{{fanout.item.vo_line}}",
        "voiceId": "{{input.voiceId}}"
      },
      "outputs": { "audio": "asset.audio" }
    },
    {
      "key": "stitch",
      "type": "Stitch",
      "input": {
        "clips": "{{steps.clips[*].clip}}",
        "audios": "{{steps.tts[*].audio}}",
        "overlays": "{{script.scenes[*].on_screen_text}}",
        "brand": "{{input.brandProfile}}",
        "preset": "{{input.preset}}"   // 1080x1920@30fps
      },
      "outputs": { "video": "asset.video" }
    },
    {
      "key": "captions",
      "type": "Captions",
      "providerPolicy": ["WHISPER_API"],
      "input": { "video": "{{steps.stitch.video}}" },
      "outputs": { "srt": "asset.caption" }
    },
    {
      "key": "publish",
      "type": "Publish",
      "input": {
        "text": "{{input.captionText}}",
        "media": ["{{steps.stitch.video}}"],
        "platforms": "{{input.platforms}}",
        "schedule": "{{input.schedule}}"
      }
    }
  ]
}
________________________________________
5) Backend APIs (NestJS)
Provider Registry
•	POST /api/ai/providers — create provider config {name, providerType, capabilities[], baseUrl?, apiKey, defaultParams}
•	GET /api/ai/providers — list per workspace
•	PUT /api/ai/providers/:id — update/enable/disable
•	DELETE /api/ai/providers/:id
Pipelines
•	POST /api/ai/pipelines — create template (specJson validated)
•	GET /api/ai/pipelines
•	PUT /api/ai/pipelines/:id
•	POST /api/ai/pipelines/:id/run — {inputJson} → returns PipelineRun.id
•	GET /api/ai/runs/:id — status, steps, assets, logs
Webhooks (per provider)
•	POST /api/ai/webhooks/:providerType — verify signature, map to StepRun by external job id, store outputs, mark DONE/FAILED
Assets
•	GET /api/ai/assets?tag=...
•	(internal) POST /internal/ai/assets/presign — pre-signed upload URLs
Publishing
•	POST /api/ai/export-to-postiz — uses existing Postiz upload + publish endpoints with correct DTOs.
________________________________________
6) Provider Adapters (Strategy Interfaces)
interface ProviderAdapter {
  testAuth(cfg: ProviderConfig): Promise<Ok>;
}

interface ResearchAdapter extends ProviderAdapter {
  summarize(input: {url?: string; text?: string; keywords?: string[]}): Promise<{brief: string; keyPoints: string[]; citations?: any[]}>;
}

interface TextAdapter extends ProviderAdapter {
  generate(input: {prompt: string; jsonSchema?: any; brand?: any}): Promise<any>; // validated JSON
}

interface ImageAdapter extends ProviderAdapter {
  generate(input: {prompt: string; aspect: string; brand?: any}): Promise<{assetUrl: string}>;
}

interface VideoClipAdapter extends ProviderAdapter {
  generate(input: {promptOrScene: any; aspect: string; durationSec: number; voice?: any}): Promise<{externalJobId: string}>;
  // Completion via webhook->StepRun or poll(externalJobId)
}

interface TTSAdapter extends ProviderAdapter {
  synth(input: {text: string; voiceId: string}): Promise<{assetUrl: string}>;
}

interface CaptionsAdapter extends ProviderAdapter {
  transcribe(input: {videoUrl: string}): Promise<{srtUrl: string}>;
}
Generic adapters for fal.ai / Replicate allow you to hit many models by just swapping model slugs.
________________________________________
7) Orchestration & Queues
•	BullMQ Queues: RUN_QUEUE (step dispatcher), POLL_QUEUE (for providers without webhooks), STITCH_QUEUE (Remotion/ffmpeg), PUBLISH_QUEUE.
•	Retry policy: 3 tries exponential; idempotency key = providerId + inputHash.
•	Webhook-first: On VideoClip.generate, store {externalJobId, providerType}; move StepRun.status=WAITING_WEBHOOK. Webhook marks completion; if none in time T, schedule polling.
________________________________________
8) Stitching & Rendering (CPU-only)
•	Remotion for programmatic composition (timeline elements: clips, VO, overlays, brand lower-thirds).
•	ffmpeg for concatenation, crossfades, volume ducking, muxing.
•	Presets: 1080x1920, 1920x1080, 1080x1080, 30 fps; H.264 + AAC; 8–12 Mbps video, 128–192 kbps audio.
•	Optional burn-in captions from .srt.
________________________________________
9) Frontend UX
Settings → Providers
•	Add provider card (logo, capabilities, API key, base URL, test connection).
•	Priority ordering per capability (drag to reorder fallbacks).
•	Cost display (static notes + observed averages from runs).
Content Inbox
•	Manage Google Alerts (RSS URL), any RSS/Atom, Reddit subs.
•	Items list → “Summarize” → “Draft ideas” → “Open in Studio.”
AI Studio → Pipeline Builder
•	Visual graph: steps as nodes; choose provider(s); param editors; validation; save as template.
•	Run panel: inputs (URL, brand, voiceId, aspect, schedule), “Run”.
•	Live run view: step status, logs, costs, artifacts.
Timeline
•	Clip bin from current run; drag to tracks; edit overlays; preview; render/export.
Publish
•	Map outputs to platform posts via existing Postiz composer/scheduler.
________________________________________
10) Cost, Quotas, Governance
•	Budgets per workspace per month; soft (warn at 80%) and hard caps.
•	Per-step cost captured from provider metadata or estimated; roll up to PipelineRun.costCents.
•	Rate limits per provider config to avoid API bans.
•	Brand guardrails: profanity/banned terms checks before publish; watermark toggle for AI media; store citations when research used.
________________________________________
11) Security
•	Encrypt provider secrets at rest; decrypt only at call.
•	RBAC: Only Owners/Admins can edit providers and pipelines.
•	Webhook signatures verified per provider; replay protection via nonce/expiry.
•	Audit log for provider changes and pipeline publishes.
________________________________________
12) Testing & Dev ergonomics
•	Provider simulators: local mock servers (ok/slow/error modes).
•	Contract tests for each adapter (Auth, 200/4xx/5xx handling, webhook mapping).
•	Golden pipelines: sample inputs → expected assets/text; run nightly.
•	Chaos flags: random failures to verify retries & fallbacks.
________________________________________
13) Deployment (your VPS)
•	Dockerized services; Postgres, Redis, Backend, Frontend, Workers, Renderer, Caddy/Nginx.
•	No GPUs required.
•	Environment flags to disable any local generation; all “generate” steps go to adapters.
•	Enable swap, keep render concurrency = 1; limit run concurrency per workspace.
________________________________________
14) Milestones (API-first)
M0 — Registry & Basics (1–1.5 wks)
•	Provider Registry + encrypted secrets + test connection
•	Pipeline spec schema + CRUD
•	Run engine skeleton + StepRun lifecycle
M1 — Text/Research + Inbox (1.5–2 wks)
•	RSS/Reddit ingest; Perplexity + GPT-5 adapters
•	Summaries, post ideas, send to Composer
M2 — VideoClip & TTS via APIs (2–3 wks)
•	Adapters for your chosen VideoClip APIs (VEO-3, “Sea Dance”) + webhooks
•	TTS adapter; basic scene fanout
M3 — Stitch & Captions (1.5–2 wks)
•	Remotion/ffmpeg stitching; captions adapter; render presets
M4 — Pipeline Builder UI & Budgets (1–2 wks)
•	Visual builder, cost/usage tracking, alerts
•	Analytics tag to feed Postiz performance back to template suggestions
________________________________________
15) Acceptance Tests
•	AT-1: Add two providers for VideoClip (primary+fallback). Kill primary; pipeline completes via fallback.
•	AT-2: Run “News-to-Story-Video” with URL → get 6-scene video (60–90s), captions, thumbnail; schedule to two platforms.
•	AT-3: Hit budget cap mid-run; step aborts gracefully; partial results visible.
•	AT-4: Webhook signature fails → request rejected & logged; step remains waiting/polls later.
•	AT-5: Change provider priority; next run uses new order (verified in logs).
________________________________________
16) Concrete developer tasks (first pass)
•	Prisma migrations for new tables above.
•	Secrets Vault service (encrypt/decrypt; key rotation stub).
•	Provider adapters: Perplexity, GPT-5 (Responses), generic Replicate/fal adapter, TTS adapter, Captions adapter, and two VideoClip adapters (names per your accounts).
•	Pipeline Engine with webhook & polling handlers; idempotent job keys.
•	Stitch service (Remotion compositions + ffmpeg scripts).
•	Frontend: Provider Settings, Pipeline Builder (JSON + visual), Run Console, Timeline.
•	Cost tracking & budget enforcement.
•	Docs: how to add a new provider (adapter template + UI form schema).
