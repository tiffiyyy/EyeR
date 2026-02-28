import React, { createContext, useContext, useState } from "react";

type TabBarVisibilityContextValue = {
  hideTabBar: boolean;
  setHideTabBar: (hide: boolean) => void;
};

const TabBarVisibilityContext = createContext<TabBarVisibilityContextValue | null>(null);

export function TabBarVisibilityProvider({ children }: { children: React.ReactNode }) {
  const [hideTabBar, setHideTabBar] = useState(false);
  return (
    <TabBarVisibilityContext.Provider value={{ hideTabBar, setHideTabBar }}>
      {children}
    </TabBarVisibilityContext.Provider>
  );
}

export function useTabBarVisibility(): TabBarVisibilityContextValue {
  const ctx = useContext(TabBarVisibilityContext);
  if (!ctx) {
    return {
      hideTabBar: false,
      setHideTabBar: () => {},
    };
  }
  return ctx;
}
