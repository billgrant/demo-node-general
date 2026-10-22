// app.js — tiny stock-quote API (Node version of the Python demo's app.py)
const express = require("express");
const axios = require("axios");

const PORT = process.env.PORT || 3000;
const SYMBOLS = ["AAPL", "MSFT", "NVDA", "GOOGL", "AMZN",
                 "META", "TSLA", "AVGO", "JPM", "V"];

// One shared HTTP client. Yahoo rejects requests with no User-Agent.
const yahoo = axios.create({
  baseURL: "https://query1.finance.yahoo.com/v8/finance/chart/",
  timeout: 10000,
  headers: { "User-Agent": "Mozilla/5.0 (demo-node-general)" },
});

async function getQuote(symbol) {
  const { data } = await yahoo.get(symbol, {
    params: { interval: "1d", range: "1d" },
  });
  const meta = data.chart.result[0].meta;
  const price = meta.regularMarketPrice;
  const prev = meta.chartPreviousClose;
  return { symbol, price, change: price - prev, pct: ((price - prev) / prev) * 100 };
}

function formatLine(q) {
  if (q.error) return `${q.symbol.padEnd(6)} error: ${q.error}`;
  const sign = q.change >= 0 ? "+" : "";
  return `${q.symbol.padEnd(6)} ${q.price.toFixed(2).padStart(10)}  ` +
         `${sign}${q.change.toFixed(2)} (${sign}${q.pct.toFixed(2)}%)`;
}

const app = express();

app.get("/quotes", async (req, res) => {
  // Fetch all 10 at once; one failure doesn't sink the rest.
  const results = await Promise.allSettled(SYMBOLS.map(getQuote));
  const quotes = results.map((r, i) =>
    r.status === "fulfilled" ? r.value : { symbol: SYMBOLS[i], error: r.reason.message }
  );

  if (req.query.format === "json") return res.json(quotes);
  res.type("text/plain").send(quotes.map(formatLine).join("\n") + "\n");
});

app.get("/healthz", (req, res) => res.send("ok\n"));

app.listen(PORT, () => console.log(`demo-node-general listening on port ${PORT}`));
