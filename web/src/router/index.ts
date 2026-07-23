import { createRouter, createWebHistory } from "vue-router";

import Defaultpage from "../views/DefaultPage.vue";
import TemplatePage from "../views/TemplatePage.vue";

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: "/defaultpage",
      name: "defaultpage",
      component: Defaultpage,
      meta: { navLabel: "Startseite / Defaultpage" },
    },
    {
      path: "/template",
      name: "template",
      component: TemplatePage,
      meta: { navLabel: "Vorlage / TemplatePage" },
    },
    {
      path: "/",
      redirect: "/defaultpage",
    },
  ],
});

export default router;
