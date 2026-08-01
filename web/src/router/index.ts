import { createRouter, createWebHistory } from "vue-router";

import Defaultpage from "../views/DefaultPage.vue";
import TemplatePage from "../views/TemplatePage.vue";
import Dashboard from "../views/Dashboard.vue";
import AdminSettings from "../views/AdminSettings.vue";

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
      path: "/dashboard",
      name: "dashboard",
      component: Dashboard,
      meta: { navLabel: "Dashboard" },
    },
    {
      path: "/admin",
      name: "admin",
      component: AdminSettings,
      meta: { navLabel: "Admin Settings" },
    },
    {
      path: "/",
      redirect: "/defaultpage",
    },
  ],
});

export default router;
