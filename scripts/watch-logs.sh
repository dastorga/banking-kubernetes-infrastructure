#!/bin/bash

# Script simple para ver logs de transacciones
echo "🏦 MONITOR DE LOGS DE TRANSACCIONES"
echo "=================================="

# Obtener el pod del backend
BACKEND_POD=$(kubectl get pods -n banking-app -l app=banking-backend --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$BACKEND_POD" ]; then
    echo "❌ No se encontró pod del backend"
    kubectl get pods -n banking-app
    exit 1
fi

echo "✅ Conectado al pod: $BACKEND_POD"
echo ""
echo "🚀 INSTRUCCIONES:"
echo "1. Ve a http://banking.local"
echo "2. Haz clic en los botones de transacciones (Depósito, Retiro, Pago)"
echo "3. Observa los logs detallados aquí abajo"
echo ""
echo "📊 LOGS EN TIEMPO REAL:"
echo "======================="

# Seguir logs en tiempo real
kubectl logs -n banking-app -f "$BACKEND_POD" --tail=10