#!/bin/bash

# 修正 SwiftLiteDB 專案結構的腳本

echo "正在修正 SwiftLiteDB 專案結構..."

# 1. 檢查是否存在測試檔案在錯誤位置
if [ -f "Sources/SwiftLiteDB/SwiftLiteDBTests.swift" ]; then
    echo "移動測試檔案到正確位置..."
    mkdir -p Tests/SwiftLiteDBTests
    mv Sources/SwiftLiteDB/SwiftLiteDBTests.swift Tests/SwiftLiteDBTests/SwiftLiteDBTests.swift
fi

# 2. 清理並重建
echo "清理專案..."
rm -rf .build

# 3. 嘗試編譯
echo "嘗試編譯專案..."
swift build

if [ $? -eq 0 ]; then
    echo "✅ 編譯成功！"
    echo "執行測試..."
    swift test
    
    if [ $? -eq 0 ]; then
        echo "✅ 測試通過！"
    else
        echo "❌ 測試失敗，但編譯成功"
    fi
else
    echo "❌ 編譯失敗，請檢查錯誤訊息"
fi

echo "修正完成！"