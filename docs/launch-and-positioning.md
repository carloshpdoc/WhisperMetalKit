# WhisperMetalKit — positioning & launch material

Internal notes + ready-to-use copy for announcing WhisperMetalKit (article, social posts, community
messages). Written 2026-06. Keep the claims honest — see the guardrails at the bottom.

---

## 1. Research verdict — does this already exist?

Checked thoroughly before launching (so we don't overclaim). Landscape as of June 2026:

| Option | Runtime | Metal | Swift API | Maintained | Via SPM |
|--------|---------|:-----:|:---------:|:----------:|:-------:|
| whisper.cpp official `xcframework` (v1.8.x) | GGML | ✅ (on releases) | ❌ raw C | ✅ | ⚠️ zip asset, not a package |
| `ggerganov/whisper.spm` | GGML | ❌ Metal excluded (2-yr TODO) | C | ❌ 2024 | ✅ |
| `exPHAT/SwiftWhisper` | GGML | ❌ CPU + CoreML | ✅ | ❌ 2024 | ✅ |
| `jordibruin/Whisper` | GGML | ❌ CPU | ✅ | ❌ 2023 | ✅ |
| `argmaxinc/WhisperKit` | **CoreML** | via CoreML (ANE/GPU) | ✅ | ✅ | ✅ |
| **WhisperMetalKit** | **GGML** | ✅ | ✅ async | ✅ | ✅ one line |

**Key finding:** whisper.cpp now publishes an official, Metal-enabled `whisper-vX-xcframework.zip` on every
release. So we are **not** the only ones with a Metal binary — upstream provides it. What still does **not**
exist is a *maintained SPM package exposing the GGML/Metal runtime behind a clean Swift API*: upstream is
raw C; the SPM wrappers are stale + CPU-only; WhisperKit is CoreML (the path that fails on iPhone for large
models). That slot is the gap WhisperMetalKit fills.

---

## 2. Why it exists (the real story)

1. Needed on-device Whisper on iPhone for an app (Voxfloy).
2. **WhisperKit (CoreML) can't run the large model on iPhone:**
   - ANE path → `MILCompilerForANE error: ANECCompile() FAILED`, `std::bad_alloc`, **CoreML error -14**
     (the AudioEncoder won't compile on the phone's ANE).
   - Forcing GPU (`MLComputeUnits.cpuAndGPU`) → **fatal assertion inside MetalPerformanceShadersGraph**
     (`cannot open input file ... .mpsgraph`) that **aborts the process** — uncatchable; no try/catch or
     timeout helps.
   - Same model + code runs fine on macOS (more ANE/GPU headroom). Not a WhisperKit bug — CoreML hitting
     hardware/compiler limits with a large encoder on a phone.
3. **whisper.cpp's GGML + Metal runtime** sidesteps CoreML/ANE/MPSGraph entirely. Same weights, same
   iPhone 17 Pro Max (A19 Pro), `large-v3-turbo-q5_0` on Metal:
   `audio IN 16.8s → audio OUT 1147ms`. **16.8 s of audio in ~1.1 s. No crash.**
4. But no maintained SPM package exposes GGML/Metal behind a clean Swift API (see verdict above). So we
   packaged it: Metal `whisper.xcframework` + `WhisperModel` (async actor) + `WhisperAudio` (AVFoundation
   resampler) + `WhisperModelDownloader`, one-line SPM, Apache-2.0.

---

## 3. Article (EN)

> # Why I built WhisperMetalKit: when CoreML can't run Whisper on your iPhone
>
> I was adding on-device dictation to my app. The obvious choice on Apple platforms is **WhisperKit** —
> excellent, actively maintained, a clean Swift API over Whisper via CoreML. On macOS it worked beautifully.
> On iPhone, it didn't.
>
> ## The wall: CoreML -14 and an uncatchable MPSGraph crash
>
> I pinned `large-v3-turbo` (great quality on my Mac). On an iPhone 17 Pro Max:
>
> - **Apple Neural Engine path** → `MILCompilerForANE error: ANECCompile() FAILED`, `std::bad_alloc`,
>   **CoreML error -14**. The ANE compiler can't build the execution plan for that encoder on the phone.
> - **Forcing the GPU** (`MLComputeUnits.cpuAndGPU`) → worse: a **fatal assertion inside
>   MetalPerformanceShadersGraph** that **aborts the process**. Uncatchable — no try/catch or timeout saves
>   you.
>
> Same model, same code: fine on Mac, dead on iPhone. Not a WhisperKit bug — CoreML hitting hardware limits
> with a large encoder on a phone.
>
> ## The fix: skip CoreML, use whisper.cpp's GGML + Metal
>
> whisper.cpp has a second runtime entirely: **GGML with a Metal backend**. It never touches CoreML, the ANE
> compiler, or MPSGraph — so those failures don't exist. Same Whisper weights, different engine.
>
> Result on the same iPhone 17 Pro Max (A19 Pro), `large-v3-turbo-q5_0` on Metal:
> **16.8 seconds of audio transcribed in 1.15 seconds. No crash.**
>
> ## So why a new package?
>
> whisper.cpp now ships an official Metal `whisper.xcframework` on its releases — great, but it's **raw C**.
> And the maintained Swift world is split: the whisper.cpp SPM wrappers are unmaintained and **CPU-only**
> (`whisper.spm`'s `Package.swift` still has a two-year-old TODO admitting it couldn't build the Metal
> shaders in SPM); **WhisperKit** gives you the lovely Swift API but via **CoreML** — the thing that just
> failed. There was no maintained package giving you whisper.cpp's **GGML/Metal runtime behind a modern
> Swift API, in one line.** So I made one.
>
> ## WhisperMetalKit
>
> ```swift
> .package(url: "https://github.com/carloshpdoc/WhisperMetalKit.git", from: "0.1.0")
> ```
> ```swift
> let model = try await WhisperModel(modelPath: url)           // ggml / gguf
> let samples = try WhisperAudio.samples(fromFile: recording)  // any file → 16kHz mono
> let result = try await model.transcribe(samples: samples, options: .init(language: "pt"))
> print(result.text)
> ```
>
> It wraps the Metal `whisper.xcframework` as a binary target and adds a small async `WhisperModel` actor, an
> AVFoundation audio resampler, and a model downloader. All Apple platforms (iOS, macOS, visionOS, tvOS).
> Apache-2.0.
>
> **When to use which:** WhisperKit if CoreML/ANE works for your model and device (often great).
> WhisperMetalKit when you want GGML/Metal — bigger/quantized models CoreML can't compile on-device, GGUF
> support, or to dodge exactly the -14 / MPSGraph failures above.
>
> github.com/carloshpdoc/WhisperMetalKit

---

## 4. X / Twitter (thread)

> 1/ Pinned `large-v3-turbo` Whisper in my iOS app via WhisperKit. Great on Mac. On iPhone: CoreML **error
> -14** (`std::bad_alloc`, ANE can't compile the encoder). Forced GPU → **uncatchable MPSGraph abort**. 🧵
>
> 2/ The model is fine — it's CoreML hitting limits with a large encoder on a phone. The fix: stop using
> CoreML. whisper.cpp has a **GGML + Metal** runtime that never touches the ANE/MPSGraph.
>
> 3/ Same iPhone 17 Pro Max, same model on Metal: **16.8s of audio → 1.15s**. No crash.
>
> 4/ Problem: no *maintained* SPM package exposes whisper.cpp's GGML/Metal behind a clean Swift API. The
> wrappers are CPU-only & stale; WhisperKit is CoreML. So I shipped one: **WhisperMetalKit** (Apache-2.0,
> one-line SPM). github.com/carloshpdoc/WhisperMetalKit

---

## 5. LinkedIn

> **On-device Whisper on iPhone: a CoreML gotcha, and the fix.**
>
> Adding dictation to my app, I hit a wall: `large-v3-turbo` ran great via WhisperKit on macOS, but on
> iPhone CoreML failed to compile the encoder (error -14, `std::bad_alloc`), and forcing the GPU crashed the
> process inside MetalPerformanceShadersGraph — uncatchable.
>
> The model wasn't the problem; CoreML was. whisper.cpp's **GGML + Metal** runtime sidesteps CoreML entirely
> and ran the same model in **1.15s for 16.8s of audio** on an A19 Pro — no crash.
>
> The catch: no maintained Swift Package exposes that GGML/Metal runtime with a modern API (existing
> wrappers are CPU-only/stale; WhisperKit is CoreML). So I open-sourced **WhisperMetalKit** — the Metal
> `whisper.xcframework` + a clean async Swift API + audio + model download, one-line SPM, Apache-2.0.
>
> If you ship on-device speech on Apple platforms, it might save you a day. Feedback welcome. 👇
> github.com/carloshpdoc/WhisperMetalKit

---

## 6. Community Slack — PT-BR

> Pessoal, soltei um pacote OSS que pode ajudar quem faz **transcrição on-device no iPhone**:
> **WhisperMetalKit** (Apache-2.0).
>
> Contexto: precisei rodar `large-v3-turbo` no iPhone. Via **WhisperKit (CoreML)** funciona no Mac, mas no
> iPhone dá **CoreML -14** (`std::bad_alloc`, o ANE não compila o encoder) e, forçando GPU, **crash no
> MetalPerformanceShadersGraph** (abort incapturável). O modelo não é o problema — é o CoreML no hardware do
> celular.
>
> A saída foi o runtime **GGML/Metal do whisper.cpp** (não passa por CoreML/ANE). Mesmo iPhone, mesmo
> modelo: **16,8s de áudio → 1,15s**, sem crash. Só que não existe pacote SPM mantido expondo GGML/Metal com
> API Swift decente (os wrappers são CPU-only/abandonados; WhisperKit é CoreML). Então empacotei:
> xcframework Metal + `WhisperModel` async + decode de áudio + download de modelo, instalação em 1 linha.
>
> github.com/carloshpdoc/WhisperMetalKit — feedback é super bem-vindo 🙏

---

## 7. Community Slack — EN

> Shipped a small OSS package for anyone doing **on-device transcription on iPhone**: **WhisperMetalKit**
> (Apache-2.0).
>
> Story: needed `large-v3-turbo` on iPhone. Via **WhisperKit (CoreML)** it's fine on Mac, but on iPhone you
> get **CoreML -14** (`std::bad_alloc`, ANE can't compile the encoder) and, forcing GPU, an **uncatchable
> MPSGraph crash**. The model's fine — it's CoreML on phone hardware. whisper.cpp's **GGML/Metal** runtime
> dodges all of that: same model, **16.8s audio → 1.15s**, no crash. No maintained SPM package exposes
> GGML/Metal with a clean Swift API (wrappers are CPU-only/stale; WhisperKit is CoreML), so I packaged it:
> Metal xcframework + async `WhisperModel` + audio decode + model download, one-line SPM.
>
> github.com/carloshpdoc/WhisperMetalKit — feedback welcome 🙏

---

## 8. Honesty guardrails (don't get "ackchually"-ed)

- ✅ Say: "the Swift DX layer over whisper.cpp's GGML/Metal runtime", "no *maintained* SPM package exposes
  GGML/Metal behind a clean API."
- ❌ Don't say: "the only Metal whisper.cpp build" / "we built the Metal xcframework." **whisper.cpp ships
  an official Metal xcframework on its releases.** Our contribution is the Swift API + DX + the CoreML
  failure context, not the binary.
- The `-14` / MPSGraph crash is a CoreML/large-model-on-phone limitation, **not a WhisperKit defect** — say
  so. WhisperKit is excellent where CoreML fits.
- Benchmark is one device (iPhone 17 Pro Max / A19 Pro), one clip — present it as such, not a universal
  number.

---

## Sources

- whisper.cpp releases (official Metal xcframework): https://github.com/ggml-org/whisper.cpp/releases
- whisper.spm Package.swift (Metal excluded, TODO): https://github.com/ggerganov/whisper.spm/blob/master/Package.swift
- exPHAT/SwiftWhisper: https://swiftpackageindex.com/exPHAT/SwiftWhisper
- argmaxinc/WhisperKit: https://github.com/argmaxinc/WhisperKit
