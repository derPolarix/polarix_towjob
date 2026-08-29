import { createI18n } from "vue-i18n";

// SSOT: the same locales/*.json files the Lua side reads via shared/locale.lua.
// Keys are semantic (e.g. "notify.vehicle_stored"); en.json is the source of truth.
import de from "../../locales/de.json";
import en from "../../locales/en.json";
import es from "../../locales/es.json";
import fr from "../../locales/fr.json";
import it from "../../locales/it.json";
import nl from "../../locales/nl.json";
import pl from "../../locales/pl.json";
import ptBr from "../../locales/pt-br.json";
import tr from "../../locales/tr.json";

export const i18n = createI18n({
  legacy: false,
  locale: "en",
  fallbackLocale: "en",
  messages: { de, en, es, fr, it, nl, pl, "pt-br": ptBr, tr },
});

// Lua sends the active Config.Language on every NUI message (client/nui/nui_messages.lua) —
// App.vue calls this so vue-i18n always matches the server config.
export function setLanguage(lang: string | undefined) {
  if (!lang) return;
  if ((i18n.global.availableLocales as string[]).includes(lang)) {
    i18n.global.locale.value = lang as never;
  }
}
