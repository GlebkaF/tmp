export async function getServerSideProps() {
  const apiBase = process.env.NEXT_PUBLIC_API_BASE_URL;
  try {
    const res = await fetch(`${apiBase}/message`);
    const data = await res.json();
    return { props: { env: data.env, message: data.message, error: null } };
  } catch (e) {
    return { props: { env: null, message: null, error: e.message } };
  }
}

export default function Home({ env, message, error }) {
  if (error) {
    return (
      <div style={{ fontFamily: "monospace", padding: 40 }}>
        <h1>Sandbox</h1>
        <p style={{ color: "red" }}>Error: {error}</p>
      </div>
    );
  }

  return (
    <div style={{ fontFamily: "monospace", padding: 40 }}>
      <h1>Sandbox</h1>
      <p><strong>Sandbox env:</strong> {env}</p>
      <p><strong>API message:</strong> {message}</p>
    </div>
  );
}
