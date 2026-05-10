import { ChevronLeft, ChevronRight } from "lucide-react";
import { Button } from "./Button";

interface PaginationProps {
  page: number;
  totalPages: number;
  onPageChange: (page: number) => void;
}

export function Pagination({ page, totalPages, onPageChange }: PaginationProps) {
  if (totalPages <= 1) return null;

  return (
    <div className="mt-6 flex items-center justify-center gap-2">
      <Button variant="ghost" size="sm" disabled={page <= 1} onClick={() => onPageChange(page - 1)}>
        <ChevronLeft className="h-4 w-4" aria-hidden />
        Prev
      </Button>
      <span className="min-w-20 text-center text-sm font-semibold text-tx-muted">
        {page} / {totalPages}
      </span>
      <Button variant="ghost" size="sm" disabled={page >= totalPages} onClick={() => onPageChange(page + 1)}>
        Next
        <ChevronRight className="h-4 w-4" aria-hidden />
      </Button>
    </div>
  );
}
