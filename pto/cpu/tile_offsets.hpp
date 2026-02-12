// Local override for CANN PTO CPU-sim headers.
//
// CANN 8.5.0 shipped `pto/cpu/tile_offsets.hpp` may have missing includes and
// a naming mismatch with `pto/cpu/TTrans.hpp` (expects `GetElementOffsetSubfractals`).
// This shim keeps the API surface expected by the headers, so we can compile
// and run CPU simulation tests without patching the CANN installation.

#ifndef PTO_CPU_TILE_OFFSETS_OVERRIDE_HPP
#define PTO_CPU_TILE_OFFSETS_OVERRIDE_HPP

#include <cstddef>
#include <type_traits>

#include <pto/common/pto_tile.hpp>

namespace pto {

template <typename TileData>
using TypeSum = std::conditional_t<std::is_same_v<typename TileData::DType, half>, float, typename TileData::DType>;

template <typename TileData>
inline std::size_t GetTileElementOffsetSubfractals(std::size_t subTileR, std::size_t innerR, std::size_t subTileC,
                                                   std::size_t innerC) {
  if constexpr (!TileData::isRowMajor && (TileData::SFractal == SLayout::RowMajor)) {
    // Nz
    return subTileC * TileData::Rows * TileData::InnerCols + subTileR * TileData::InnerNumel +
           innerR * TileData::InnerCols + innerC;
  } else if constexpr (TileData::isRowMajor && (TileData::SFractal == SLayout::ColMajor)) {
    // Zn
    return subTileR * TileData::Cols * TileData::InnerRows + subTileC * TileData::InnerNumel +
           innerC * TileData::InnerRows + innerR;
  } else if constexpr (TileData::isRowMajor && (TileData::SFractal == SLayout::RowMajor)) {
    // Zz
    return subTileR * TileData::Cols * TileData::InnerRows + subTileC * TileData::InnerNumel +
           innerR * TileData::InnerCols + innerC;
  } else {
    static_assert(sizeof(TileData) == 0, "Invalid SLayout for GetTileElementOffsetSubfractals");
  }
}

// Compatibility alias expected by `pto/cpu/TTrans.hpp` in this environment.
template <typename TileData>
inline std::size_t GetElementOffsetSubfractals(std::size_t subTileR, std::size_t innerR, std::size_t subTileC,
                                               std::size_t innerC) {
  return GetTileElementOffsetSubfractals<TileData>(subTileR, innerR, subTileC, innerC);
}

template <typename TileData>
inline std::size_t GetTileElementOffsetPlain(std::size_t r, std::size_t c) {
  if constexpr (TileData::isRowMajor) {
    return r * TileData::Cols + c;
  } else {
    return c * TileData::Rows + r;
  }
}

template <typename TileData>
inline std::size_t GetTileElementOffset(std::size_t r, std::size_t c) {
  if constexpr (TileData::SFractal == SLayout::NoneBox) {
    return GetTileElementOffsetPlain<TileData>(r, c);
  } else {
    return GetTileElementOffsetSubfractals<TileData>(r / TileData::InnerRows, r % TileData::InnerRows,
                                                     c / TileData::InnerCols, c % TileData::InnerCols);
  }
}

}  // namespace pto

#endif

