import { redirect } from "next/navigation";
export default async function P({ params }) {
  redirect(`/${(await params).project}/project/scope`);
}
