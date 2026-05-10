import { useEffect } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { authService } from "@/services/auth.service";
import { API_TOKEN_STORAGE_KEY } from "@/services/api";
import { useAppStore } from "@/store/useAppStore";
import type { LoginPayload, RegisterPayload, UserUpdatePayload } from "@/types/user";

export function useAuth() {
  const queryClient = useQueryClient();
  const token = useAppStore((state) => state.token);
  const user = useAppStore((state) => state.user);
  const setAuth = useAppStore((state) => state.setAuth);
  const setUser = useAppStore((state) => state.setUser);
  const clearAuth = useAppStore((state) => state.clearAuth);

  useEffect(() => {
    if (token && typeof window !== "undefined") {
      window.localStorage.setItem(API_TOKEN_STORAGE_KEY, token);
    }
  }, [token]);

  const meQuery = useQuery({
    queryKey: ["auth", "me"],
    queryFn: authService.me,
    enabled: Boolean(token),
    retry: false,
  });

  useEffect(() => {
    if (meQuery.data) {
      setUser(meQuery.data);
    }
  }, [meQuery.data, setUser]);

  const loginMutation = useMutation({
    mutationFn: (payload: LoginPayload) => authService.login(payload),
    onSuccess: async (data) => {
      setAuth(data.access_token);
      const me = await queryClient.fetchQuery({
        queryKey: ["auth", "me"],
        queryFn: authService.me,
      });
      setUser(me);
    },
  });

  const registerMutation = useMutation({
    mutationFn: (payload: RegisterPayload) => authService.register(payload),
  });

  const updateProfileMutation = useMutation({
    mutationFn: (payload: UserUpdatePayload) => authService.updateMe(payload),
    onSuccess: (nextUser) => {
      setUser(nextUser);
      queryClient.setQueryData(["auth", "me"], nextUser);
    },
  });

  function logout() {
    clearAuth();
    queryClient.removeQueries({ queryKey: ["auth"] });
  }

  return {
    token,
    user: meQuery.data ?? user,
    isAuthenticated: Boolean(token),
    isAdmin: (meQuery.data ?? user)?.Role === "admin",
    isLoadingUser: meQuery.isLoading,
    login: loginMutation,
    register: registerMutation,
    updateProfile: updateProfileMutation,
    logout,
  };
}
