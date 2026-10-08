import { createI18n } from "vue-i18n";

// Same locales/*.json as the Lua side (shared/locale.lua).
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

// Called from App.vue with the language Lua sends on every NUI message.
export function setLanguage(lang: string | undefined) {
  if (!lang) return;
  if ((i18n.global.availableLocales as string[]).includes(lang)) {
    i18n.global.locale.value = lang as never;
  }
}
