"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { FormEvent, useState } from "react";
import { UserPlus } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import { useAuth } from "@/hooks/useAuth";
import { getApiErrorMessage } from "@/services/api";

export default function RegisterPage() {
  const router = useRouter();
  const { register, login } = useAuth();
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    try {
      await register.mutateAsync({ username, email, password });
      await login.mutateAsync({ username, password });
      router.push("/");
    } catch (err) {
      setError(getApiErrorMessage(err));
    }
  }

  return (
    <main className="page-shell flex min-h-[calc(100vh-4rem)] items-center justify-center">
      <section className="w-full max-w-md rounded-def border border-bd bg-surface p-6 shadow-floating">
        <div className="mb-6">
          <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-accent text-white">
            <UserPlus className="h-6 w-6" aria-hidden />
          </div>
          <h1 className="font-heading text-3xl font-bold text-tx">Create account</h1>
          <p className="mt-2 text-sm text-tx-muted">Register through `/api/v1/auth/register`, then login automatically.</p>
        </div>
        <form onSubmit={submit} className="space-y-4">
          <Input label="Username" value={username} onChange={(event) => setUsername(event.target.value)} required autoComplete="username" />
          <Input label="Email" value={email} onChange={(event) => setEmail(event.target.value)} required type="email" autoComplete="email" />
          <Input label="Password" value={password} onChange={(event) => setPassword(event.target.value)} required type="password" autoComplete="new-password" />
          {error ? <p className="text-sm font-semibold text-[var(--red)]">{error}</p> : null}
          <Button type="submit" className="w-full" isLoading={register.isPending || login.isPending}>
            Create account
          </Button>
        </form>
        <p className="mt-5 text-center text-sm text-tx-muted">
          Already have an account?{" "}
          <Link href="/auth/login" className="font-bold text-accent hover:underline">
            Login
          </Link>
        </p>
      </section>
    </main>
  );
}