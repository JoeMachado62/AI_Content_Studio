PRD — Postiz “AI Content Studio” (API-First, Pluggable Providers)
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
