/// <reference types="vite/client" />

declare module "*.vue" {
  import type { DefineComponent } from "vue";
  const component: DefineComponent<{}, {}, any>;
  export default component;
}

declare global {
  function GetParentResourceName(): string;
}

declare module "@vue/runtime-core" {
  interface ComponentCustomProperties {
    $persistantStore: import("./stores/persistantStore").PersistantStore;
    $router: import("vue-router").Router;
  }
}

export {};