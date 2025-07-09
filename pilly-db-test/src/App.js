import React, { useEffect, useState } from "react";

function PillSearchApp() {
  const [userId, setUserId] = useState(null);
  const [pillSeq, setPillSeq] = useState("");
  const [logs, setLogs] = useState([]);
  const [result, setResult] = useState(null);
  const [selectedLog, setSelectedLog] = useState(null);

  // ✅ 너의 컴퓨터 IP를 여기에 지정
  const BASE_URL = "https://4bca4da51bbf.ngrok-free.app";

  function generateUUID() {
    return crypto.randomUUID ? crypto.randomUUID() : "user-" + Date.now();
  }

  useEffect(() => {
  let id = localStorage.getItem("user_id");
    if (!id) {
      id = generateUUID();
      localStorage.setItem("user_id", id);
      console.log("✅ 새로운 user_id 저장됨:", id);
    } else {
      console.log("✅ 기존 user_id:", id);
    }
    setUserId(id);
  }, []);


  useEffect(() => {
    if (userId) {
      fetchLogs(userId);
    }
  }, [userId]);

  async function fetchLogs(id) {
    try {
      const res = await fetch(`${BASE_URL}/api/get_search_logs?user_id=${id}`);
      const contentType = res.headers.get("content-type");
      console.log("응답 Content-Type:", contentType);

      if (!res.ok) throw new Error("서버 응답 오류: " + res.status);

      if (contentType && contentType.includes("application/json")) {
        const data = await res.json();
        console.log("받은 검색 기록 데이터:", data);
        setLogs(data);
      } else {
        const text = await res.text();
        console.error("예상치 못한 응답 형식:", text);
        throw new Error("서버가 JSON이 아닌 HTML을 반환했습니다.");
      }
    } catch (e) {
      console.error("최근 검색 기록 불러오기 실패", e);
      setLogs([]);
    }
  }



  async function handleSearch() {
    if (!pillSeq) {
      alert("약 시퀀스를 입력하세요.");
      return;
    }

    try {
      const res = await fetch(`${BASE_URL}/api/log_search`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          user_id: userId,
          pill_sequence: String(pillSeq)
        })
      });

      const data = await res.json();
      if (data.error) {
        alert("에러: " + data.error);
      } else {
        setResult(data.result);
        setSelectedLog({
          pill_sequence: pillSeq,
          pill_name: data.pill_name || "이름 없음"
        });
        fetchLogs(userId);
      }
    } catch (e) {
      alert("검색 중 에러 발생");
      console.error(e);
    }
  }

  async function showResult(seq) {
    try {
      const res = await fetch(`${BASE_URL}/api/get_search_result?user_id=${userId}&pill_sequence=${String(seq)}`);
      const data = await res.json();

      if (data.error) {
        alert("데이터 없음");
      } else {
        setResult(data.search_result);
        setSelectedLog({
          pill_sequence: data.pill_sequence,
          pill_name: data.pill_name
        });
      }
    } catch (e) {
      alert("상세 조회 중 에러 발생");
      console.error(e);
    }
  }

  return (
    <div style={{ padding: 20 }}>
      <h2>알약 DUR 검색</h2>

      <div>
        <input
          placeholder="약 시퀀스 입력"
          value={pillSeq}
          onChange={(e) => setPillSeq(e.target.value)}
        />
        <button onClick={handleSearch} style={{ marginLeft: 10 }}>
          검색
        </button>
      </div>

      <h3>최근 검색 기록 (최대 5개)</h3>
      <ul>
        {logs.length === 0 && <li>최근 검색 기록이 없습니다.</li>}
        {logs.map((log) => (
          <li
            key={log.pill_sequence}
            style={{ cursor: "pointer", marginBottom: 5 }}
            onClick={() => showResult(log.pill_sequence)}
          >
            <b>{log.pill_name || "이름 없음"}</b> - {new Date(log.search_time).toLocaleString()}
          </li>
        ))}
      </ul>

      {result && selectedLog && (
        <div style={{ marginTop: 30 }}>
          <h3>검색 결과</h3>
          <p><b>약 시퀀스:</b> {selectedLog.pill_sequence}</p>
          <p><b>알약 이름:</b> {selectedLog.pill_name || "이름 없음"}</p>
          {Object.entries(result).map(([category, items]) => (
            <div key={category} style={{ marginBottom: 30 }}>
              <h4>{category}</h4>
              <table style={{ width: "100%", borderCollapse: "collapse", marginTop: 10 }}>
                <thead>
                  <tr>
                    {category === "병용금기" && (
                      <th style={{ borderBottom: "1px solid black" }}>상대 약제명</th>
                    )}
                    <th style={{ borderBottom: "1px solid black" }}>주의/금기 사유</th>
                  </tr>
                </thead>
                <tbody>
                  {items.map((item, idx) => (
                    <tr key={idx}>
                      {category === "병용금기" && item.item_name ? (
                        <td style={{ padding: 5, borderBottom: "1px solid #ccc" }}>{item.item_name}</td>
                      ) : category === "병용금기" ? (
                        <td style={{ padding: 5, borderBottom: "1px solid #ccc" }}>없음</td>
                      ) : null}
                      <td style={{ padding: 5, borderBottom: "1px solid #ccc" }}>{item.prohibition}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default PillSearchApp;
