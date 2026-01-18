package internal

// MemCache is the memory cache for storing the counts.
type memCache struct {
	counts map[string]int
}

// Inc a label by one.
func (m *memCache) inc(label string) {
	if _, ok := m.counts[label]; !ok {
		m.counts[label] = 0
	}

	m.counts[label]++
}
