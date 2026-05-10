"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { FormEvent, Suspense, useState } from "react";
import { LogIn } from "lucide-react";
import { useQueryClient } from "@tanstack/react-query";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import { useAuth } from "@/hooks/useAuth";
import { getApiErrorMessage } from "@/services/api";
import type { User } from "@/types/user";

export default function LoginPage() {
  return (
    <Suspense>
      <LoginForm />
    </Suspense>
  );
}

function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const queryClient = useQueryClient();
  const { login } = useAuth();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    try {
      await login.mutateAsync({ username, password });

      // After successful login, check if user is admin and redirect accordingly
      const me = queryClient.getQueryData<User>(["auth", "me"]);

      if (me?.Role === "admin") {
        router.push("/admin");
      } else {
        router.push(params.get("next") ?? "/");
      }
    } catch (err) {
      setError(getApiErrorMessage(err));
    }
  }

  return (
    <main className="page-shell flex min-h-[calc(100vh-4rem)] items-center justify-center">
      <section className="w-full max-w-md rounded-def border border-bd bg-surface p-6 shadow-floating">
        <div className="mb-6">
          <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-accent text-white">
            <LogIn className="h-6 w-6" aria-hidden />
          </div>
          <h1 className="font-heading text-3xl font-bold text-tx">Login</h1>
          <p className="mt-2 text-sm text-tx-muted">Use your backend JWT account to unlock lists, rating, comments, and reading history.</p>
        </div>
        <form onSubmit={submit} className="space-y-4">
          <Input label="Username" value={username} onChange={(event) => setUsername(event.target.value)} required autoComplete="username" />
          <Input label="Password" value={password} onChange={(event) => setPassword(event.target.value)} required type="password" autoComplete="current-password" />
          {error ? <p className="text-sm font-semibold text-[var(--red)]">{error}</p> : null}
          <Button type="submit" className="w-full" isLoading={login.isPending}>
            Login
          </Button>
        </form>
        <p className="mt-5 text-center text-sm text-tx-muted">
          New here?{" "}
          <Link href="/auth/register" className="font-bold text-accent hover:underline">
            Create account
          </Link>
        </p>
      </section>
    </main>
  );
}