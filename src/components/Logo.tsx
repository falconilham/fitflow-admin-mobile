import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Dumbbell } from 'lucide-react-native';

interface LogoProps {
  size?: 'small' | 'medium' | 'large';
}

export default function Logo({ size = 'large' }: LogoProps) {
  const isLarge = size === 'large';
  const iconBoxSize = isLarge ? 56 : 40;
  const iconSize = isLarge ? 28 : 20;
  const fontSize = isLarge ? 28 : 20;

  return (
    <View style={styles.container}>
      <View
        style={[styles.iconBox, { width: iconBoxSize, height: iconBoxSize }]}
      >
        <Dumbbell size={iconSize} color="black" />
      </View>
      <View style={styles.textContainer}>
        <Text style={[styles.textBase, styles.textFit, { fontSize }]}>FIT</Text>
        <Text style={[styles.textBase, styles.textFlow, { fontSize }]}>
          FLOW.ID
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'column',
    alignItems: 'center',
    gap: 16,
  },
  iconBox: {
    backgroundColor: '#C8F000',
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#C8F000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 10,
    elevation: 8,
  },
  textContainer: {
    flexDirection: 'row',
    alignItems: 'baseline',
  },
  textBase: {
    fontWeight: '900',
    letterSpacing: -1,
  },
  textFit: {
    color: '#FFFFFF',
  },
  textFlow: {
    color: '#C8F000',
  },
});
