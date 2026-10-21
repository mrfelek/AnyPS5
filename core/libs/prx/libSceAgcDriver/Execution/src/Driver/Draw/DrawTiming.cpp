#include "prx/libSceAgcDriver/Execution/include/ProfileOutput.hpp"
#include "prx/libSceAgcDriver/Execution/include/Driver/Driver.hpp"
#include "prx/libSceAgcDriver/Execution/include/Driver/Draw/DrawTiming.hpp"

namespace AgcDriver::DriverDetail {

PendingDrawPhases& Driver::pendingDrawPhases() {
    static thread_local PendingDrawPhases pending;
    return pending;
}

void Driver::addDrawPhases(const std::array<double, DrawDriverPhaseCount>& ms, bool drawn, std::uint64_t captures, int kind) {
    std::lock_guard lock(drawPhasesMutex);
    static std::array<std::array<double, DrawDriverPhaseCount>, 5> kindMs{};
    static std::array<std::uint64_t, 5> kindCount{};
    if (drawn && kind >= 0 && kind < 5) {
        for (std::size_t i = 0; i < DrawDriverPhaseCount; ++i) kindMs[kind][i] += ms[i];
        ++kindCount[kind];
    }
    auto& totals = drawPhaseTotals;
    for (std::size_t i = 0; i < DrawDriverPhaseCount; ++i) totals.ms[i] += ms[i];
    ++totals.packets;
    if (drawn) ++totals.drawn;
    totals.captures += captures;
    const auto now = std::chrono::steady_clock::now();
    if (now - totals.lastReport < std::chrono::seconds(10)) return;
    totals.lastReport = now;
    std::string report;
    double total = 0;
    for (std::size_t i = 0; i < DrawDriverPhaseCount; ++i) {
        char text[64];
        std::snprintf(text, sizeof(text), " %s %.1f", DrawDriverPhaseNames[i], totals.ms[i] * 1000 / static_cast<double>(totals.packets));
        report += text;
        total += totals.ms[i];
    }
    AgcDriver::ProfilePrint_nid_no_patch( "[draw] driver phases (10 s, %llu draw packets, %llu drawn, %llu captures), us per packet:%s, total %.1f (%.1f ms; Graphics::Draw %.1f ms, skipped %.1f ms)\n", static_cast<unsigned long long>(totals.packets), static_cast<unsigned long long>(totals.drawn), static_cast<unsigned long long>(totals.captures), report.c_str(), total * 1000 / static_cast<double>(totals.packets), total, totals.ms[DrawRowGraphics], totals.ms[DrawRowSkipped]);
    static const char* kindNames[5] = {"unknown", "full hit", "relocated hit", "partial (stages reused)", "miss"};
    for (std::size_t k = 0; k < 5; ++k) {
        if (kindCount[k] == 0) continue;
        std::string row;
        double sum = 0;
        for (std::size_t i = 0; i < DrawDriverPhaseCount; ++i) {
            const double us = kindMs[k][i] * 1000 / static_cast<double>(kindCount[k]);
            sum += us;
            if (us < 0.05) continue;
            char text[64];
            std::snprintf(text, sizeof(text), " %s %.1f", DrawDriverPhaseNames[i], us);
            row += text;
        }
        std::fprintf(stderr, "[tmp-phases] %s: %llu draws, us per draw:%s, total %.1f\n", kindNames[k], static_cast<unsigned long long>(kindCount[k]), row.c_str(), sum);
    }
    kindMs = {};
    kindCount = {};
    totals.ms = {};
    totals.packets = totals.drawn = totals.captures = 0;
}

void DrawPhaseTiming::Phase(DrawDriverPhase which) {
    if (!profile) return;
    const auto now = std::chrono::steady_clock::now();
    phaseMs[which] += std::chrono::duration<double, std::milli>(now - phaseLap).count();
    phaseLap = now;
}

}
