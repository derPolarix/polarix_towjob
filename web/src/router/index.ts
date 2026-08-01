import { createRouter, createWebHistory } from "vue-router";

import Dashboard from "../views/Dashboard.vue";
import AdminSettings from "../views/AdminSettings.vue";

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
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
      redirect: "/dashboard",
    },
  ],
});

export default router;
