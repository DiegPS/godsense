#include <windows.h>
#include <cmath>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <map>
#include <mutex>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>
#include "third_party/sherpa-onnx-c-api.h"

namespace {
constexpr uint32_t kMagic = 0x31545347;  // GST1, little endian.
constexpr uint32_t kMaxString = 1024 * 1024;
constexpr uint32_t kMaxSamples = 16000000;
using Fields = std::map<std::string, std::string>;

void Read(void* data, uint32_t size) {
  auto* out = static_cast<char*>(data);
  while (size) {
    DWORD received = 0;
    if (!ReadFile(GetStdHandle(STD_INPUT_HANDLE), out, size, &received, nullptr) || !received)
      throw std::runtime_error("Speech input closed");
    out += received;
    size -= received;
  }
}
void Write(const void* data, uint32_t size) {
  const auto* in = static_cast<const char*>(data);
  while (size) {
    DWORD written = 0;
    if (!WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), in, size, &written, nullptr) || !written)
      ExitProcess(125);
    in += written;
    size -= written;
  }
}
uint32_t ReadInt() { uint32_t value; Read(&value, sizeof(value)); return value; }
void WriteInt(uint32_t value) { Write(&value, sizeof(value)); }
std::wstring Wide(const std::string& value) {
  if (value.empty()) return {};
  const int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                                       static_cast<int>(value.size()), nullptr, 0);
  if (!count) throw std::runtime_error("Invalid speech UTF-8");
  std::wstring result(count, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), result.data(), count);
  return result;
}
std::string ReadString() {
  const uint32_t size = ReadInt();
  if (size > kMaxString) throw std::runtime_error("Speech field too large");
  std::string value(size, '\0');
  Read(value.data(), size);
  if (value.find('\0') != std::string::npos) throw std::runtime_error("Invalid speech field");
  Wide(value);  // Validate UTF-8 before any field reaches the native API.
  return value;
}
void WriteString(const std::string& value) {
  WriteInt(static_cast<uint32_t>(value.size()));
  Write(value.data(), static_cast<uint32_t>(value.size()));
}
Fields ReadFields() {
  const uint32_t count = ReadInt();
  if (count > 64) throw std::runtime_error("Too many speech fields");
  Fields fields;
  size_t total = 0;
  for (uint32_t i = 0; i < count; ++i) {
    auto key = ReadString();
    auto value = ReadString();
    total += key.size() + value.size();
    if (total > 4 * kMaxString || !fields.emplace(key, value).second)
      throw std::runtime_error("Invalid speech message");
  }
  return fields;
}
const char* Field(const Fields& fields, const std::string& key) {
  const auto found = fields.find(key);
  return found == fields.end() ? "" : found->second.c_str();
}
float Number(const Fields& fields, const std::string& key, float minimum, float maximum) {
  const std::string value = Field(fields, key);
  size_t used = 0;
  const float number = std::stof(value, &used);
  if (used != value.size() || !std::isfinite(number) || number < minimum || number > maximum)
    throw std::runtime_error("Invalid speech numeric parameter");
  return number;
}
int Integer(const Fields& fields, const std::string& key, int minimum, int maximum) {
  const float number = Number(fields, key, static_cast<float>(minimum), static_cast<float>(maximum));
  if (std::floor(number) != number) throw std::runtime_error("Invalid speech integer");
  return static_cast<int>(number);
}
template <typename T> T Function(HMODULE library, const char* name) {
  const auto address = GetProcAddress(library, name);
  if (!address) throw std::runtime_error("Missing speech runtime symbol");
  return reinterpret_cast<T>(address);
}
DWORD WINAPI WatchParent(void* process) {
  WaitForSingleObject(static_cast<HANDLE>(process), INFINITE);
  ExitProcess(124);
}
struct Command { uint32_t type; Fields fields; };
struct Inbox {
  std::mutex mutex;
  std::condition_variable available;
  std::deque<Command> commands;
};
void ReadCommands(Inbox* inbox) {
  try {
    while (true) {
      const uint32_t type = ReadInt();
      if (type != 1 && type != 2) throw std::runtime_error("Unknown speech command");
      Command command{type, type == 1 ? ReadFields() : Fields{}};
      {
        std::lock_guard<std::mutex> lock(inbox->mutex);
        if (inbox->commands.size() >= 2) throw std::runtime_error("Speech command queue full");
        inbox->commands.push_back(std::move(command));
      }
      inbox->available.notify_one();
    }
  } catch (...) {
    // EOF includes the proxy isolate disappearing during model loading or an
    // inference call. No Dart callback exists inside this process.
    ExitProcess(124);
  }
}
SherpaOnnxOfflineTtsConfig ModelConfig(const Fields& fields) {
  SherpaOnnxOfflineTtsConfig config{};
  auto file = [&](const char* key) { return Field(fields, std::string("file.") + key); };
  auto& model = config.model;
  model.num_threads = Integer(fields, "threads", 1, 128);
  model.provider = "cpu";
  config.max_num_sentences = Integer(fields, "maxSentences", 1, 100);
  config.silence_scale = Number(fields, "silenceScale", 0, 5);
  const std::string family = Field(fields, "family");
  if (family == "vits") {
    model.vits.model = file("model"); model.vits.lexicon = file("lexicon");
    model.vits.tokens = file("tokens"); model.vits.data_dir = file("dataDir");
    model.vits.noise_scale = 0.667f; model.vits.noise_scale_w = 0.8f; model.vits.length_scale = 1;
  } else if (family == "matcha") {
    model.matcha.acoustic_model = file("acousticModel"); model.matcha.vocoder = file("vocoder");
    model.matcha.lexicon = file("lexicon"); model.matcha.tokens = file("tokens");
    model.matcha.data_dir = file("dataDir"); model.matcha.noise_scale = 0.667f; model.matcha.length_scale = 1;
  } else if (family == "kokoro") {
    model.kokoro.model = file("model"); model.kokoro.voices = file("voices");
    model.kokoro.tokens = file("tokens"); model.kokoro.data_dir = file("dataDir");
    model.kokoro.lexicon = file("lexicon"); model.kokoro.length_scale = 1;
  } else if (family == "kitten") {
    model.kitten.model = file("model"); model.kitten.voices = file("voices");
    model.kitten.tokens = file("tokens"); model.kitten.data_dir = file("dataDir"); model.kitten.length_scale = 1;
  } else if (family == "zipvoice") {
    model.zipvoice.tokens = file("tokens"); model.zipvoice.encoder = file("encoder");
    model.zipvoice.decoder = file("decoder"); model.zipvoice.vocoder = file("vocoder");
    model.zipvoice.data_dir = file("dataDir"); model.zipvoice.lexicon = file("lexicon");
    model.zipvoice.feat_scale = 0.1f; model.zipvoice.t_shift = 0.5f;
    model.zipvoice.target_rms = 0.1f; model.zipvoice.guidance_scale = 1;
  } else if (family == "pocket") {
    model.pocket.lm_flow = file("lmFlow"); model.pocket.lm_main = file("lmMain");
    model.pocket.encoder = file("encoder"); model.pocket.decoder = file("decoder");
    model.pocket.text_conditioner = file("textConditioner"); model.pocket.vocab_json = file("vocabJson");
    model.pocket.token_scores_json = file("tokenScoresJson"); model.pocket.voice_embedding_cache_capacity = 50;
  } else if (family == "supertonic") {
    model.supertonic.duration_predictor = file("durationPredictor"); model.supertonic.text_encoder = file("textEncoder");
    model.supertonic.vector_estimator = file("vectorEstimator"); model.supertonic.vocoder = file("vocoder");
    model.supertonic.tts_json = file("ttsJson"); model.supertonic.unicode_indexer = file("unicodeIndexer");
    model.supertonic.voice_style = file("voiceStyle");
  } else { throw std::runtime_error("Unknown speech model family"); }
  return config;
}
}  // namespace

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
  WriteInt(kMagic);
  try {
    if (ReadInt() != kMagic) throw std::runtime_error("Unsupported speech protocol");
    const DWORD parent = ReadInt();
    HANDLE parent_handle = OpenProcess(SYNCHRONIZE, FALSE, parent);
    if (!parent_handle) throw std::runtime_error("Speech parent unavailable");
    HANDLE monitor = CreateThread(nullptr, 0, WatchParent, parent_handle, 0, nullptr);
    if (!monitor) throw std::runtime_error("Speech parent monitor failed");
    CloseHandle(monitor);
    const Fields fields = ReadFields();
    // Process-owned so exception unwinding cannot destroy synchronization
    // objects while the detached input monitor is still accessing them.
    auto* inbox = new Inbox;
    std::thread(ReadCommands, inbox).detach();
    // Find dependencies alongside the helper, never in a user-supplied search
    // path. Explicitly preload our ONNX Runtime before loading Sherpa.
    std::vector<wchar_t> module(32768);
    const DWORD length = GetModuleFileNameW(nullptr, module.data(), static_cast<DWORD>(module.size()));
    if (!length || length >= module.size()) throw std::runtime_error("Speech executable path unavailable");
    const std::wstring path(module.data(), length);
    const std::wstring directory = path.substr(0, path.find_last_of(L"\\/"));
    SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_SYSTEM32 | LOAD_LIBRARY_SEARCH_USER_DIRS);
    AddDllDirectory(directory.c_str());
    if (!LoadLibraryExW((directory + L"\\onnxruntime.dll").c_str(), nullptr,
                        LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32))
      throw std::runtime_error("ONNX Runtime unavailable");
    HMODULE library = LoadLibraryExW((directory + L"\\sherpa-onnx-c-api.dll").c_str(), nullptr,
                        LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!library) throw std::runtime_error("Speech runtime unavailable");
    auto create = Function<decltype(&SherpaOnnxCreateOfflineTts)>(library, "SherpaOnnxCreateOfflineTts");
    auto destroy = Function<decltype(&SherpaOnnxDestroyOfflineTts)>(library, "SherpaOnnxDestroyOfflineTts");
    auto generate = Function<decltype(&SherpaOnnxOfflineTtsGenerateWithConfig)>(library, "SherpaOnnxOfflineTtsGenerateWithConfig");
    auto free_audio = Function<decltype(&SherpaOnnxDestroyOfflineTtsGeneratedAudio)>(library, "SherpaOnnxDestroyOfflineTtsGeneratedAudio");
    auto sample_rate = Function<decltype(&SherpaOnnxOfflineTtsSampleRate)>(library, "SherpaOnnxOfflineTtsSampleRate");
    auto read_wave = Function<decltype(&SherpaOnnxReadWave)>(library, "SherpaOnnxReadWave");
    auto free_wave = Function<decltype(&SherpaOnnxFreeWave)>(library, "SherpaOnnxFreeWave");
    const auto config = ModelConfig(fields);
    const auto* tts = create(&config);
    if (!tts) throw std::runtime_error("Speech model could not be loaded");
    WriteInt(0); WriteInt(static_cast<uint32_t>(sample_rate(tts)));
    while (true) {
      Command command;
      {
        std::unique_lock<std::mutex> lock(inbox->mutex);
        inbox->available.wait(lock, [&] { return !inbox->commands.empty(); });
        command = std::move(inbox->commands.front()); inbox->commands.pop_front();
      }
      if (command.type == 2) {
        destroy(tts); WriteInt(0);
        // All model resources have been released normally. The OS releases
        // the process-owned input monitor and its bounded inbox on exit.
        ExitProcess(0);
      }
      auto& request = command.fields;
      SherpaOnnxGenerationConfig generation{};
      generation.sid = Integer(request, "speakerId", 0, 100000);
      generation.speed = Number(request, "speed", 0.01f, 100);
      generation.num_steps = Integer(request, "steps", 1, 1000);
      generation.silence_scale = config.silence_scale;
      generation.reference_text = Field(request, "referenceText");
      const std::string extra = Field(request, "extra");
      generation.extra = extra.c_str();
      const std::string reference_path = Field(request, "referenceAudio");
      const SherpaOnnxWave* reference = nullptr;
      if (!reference_path.empty()) {
        reference = read_wave(reference_path.c_str());
        if (!reference || reference->num_samples <= 0 || reference->sample_rate <= 0)
          throw std::runtime_error("Speech reference audio unavailable");
        generation.reference_audio = reference->samples;
        generation.reference_audio_len = reference->num_samples;
        generation.reference_sample_rate = reference->sample_rate;
      }
      const auto* audio = generate(tts, Field(request, "text"), &generation, nullptr, nullptr);
      if (reference) free_wave(reference);
      if (!audio || audio->n < 0 || static_cast<uint32_t>(audio->n) > kMaxSamples || audio->sample_rate <= 0)
        throw std::runtime_error("Invalid native speech output");
      WriteInt(0); WriteInt(static_cast<uint32_t>(audio->sample_rate)); WriteInt(static_cast<uint32_t>(audio->n));
      Write(audio->samples, static_cast<uint32_t>(audio->n) * sizeof(float));
      free_audio(audio);
    }
  } catch (const std::exception& error) {
    WriteInt(1); WriteString(error.what());
    ExitProcess(10);
  } catch (...) {
    WriteInt(1); WriteString("Native speech failed");
    ExitProcess(10);
  }
}
