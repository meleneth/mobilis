package app

import (
    "context"
    "encoding/json"
    "errors"
    "fmt"
    "os"
    "strings"

    "github.com/twmb/franz-go/pkg/kgo"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/propagation"
    "go.opentelemetry.io/otel/trace"
)

type Kafka struct { client *kgo.Client }

type kafkaHeaders []kgo.RecordHeader

func (h *kafkaHeaders) Get(key string) string {
    for _, header := range *h { if header.Key == key { return string(header.Value) } }
    return ""
}
func (h *kafkaHeaders) Set(key, value string) { *h = append(*h, kgo.RecordHeader{Key: key, Value: []byte(value)}) }
func (h *kafkaHeaders) Keys() []string {
    keys := make([]string, 0, len(*h))
    for _, header := range *h { keys = append(keys, header.Key) }
    return keys
}

func declaredTopic(topic string) bool {
    for _, allowed := range strings.Split(os.Getenv("MOBILIS_KAFKA_PUBLISH_TOPICS"), ",") {
        if allowed == topic { return true }
    }
    return false
}

func NewKafka() (*Kafka, error) {
    client, err := kgo.NewClient(kgo.SeedBrokers(os.Getenv("KAFKA_BOOTSTRAP_SERVERS")),
        kgo.ProducerBatchCompression(kgo.NoCompression()))
    if err != nil { return nil, err }
    return &Kafka{client: client}, nil
}

func (k *Kafka) Close() { k.client.Close() }

// Publish returns only after the broker acknowledges the command.
func (k *Kafka) Publish(ctx context.Context, topic, key string, event any, headers map[string]string) (int32, int64, error) {
    if !declaredTopic(topic) { return 0, 0, fmt.Errorf("undeclared Kafka topic %q", topic) }
    if key == "" { return 0, 0, errors.New("Kafka key is required") }
    value, err := json.Marshal(event)
    if err != nil { return 0, 0, err }
    ctx, span := otel.Tracer("mobilis.kafka").Start(ctx, "kafka publish", trace.WithSpanKind(trace.SpanKindProducer))
    defer span.End()
    recordHeaders := kafkaHeaders{}
    for name, value := range headers { recordHeaders.Set(name, value) }
    propagation.TraceContext{}.Inject(ctx, &recordHeaders)
    record := &kgo.Record{Topic: topic, Key: []byte(key), Value: value, Headers: recordHeaders}
    results := k.client.ProduceSync(ctx, record)
    if err := results.FirstErr(); err != nil { span.RecordError(err); return 0, 0, err }
    return record.Partition, record.Offset, nil
}

type KafkaConsumer struct { client *kgo.Client }

func NewKafkaConsumer(topic, group string) (*KafkaConsumer, error) {
    allowed := false
    for _, subscription := range strings.Split(os.Getenv("MOBILIS_KAFKA_SUBSCRIPTIONS"), ",") {
        if subscription == topic+":"+group { allowed = true; break }
    }
    if !allowed { return nil, fmt.Errorf("undeclared Kafka subscription %s:%s", topic, group) }
    client, err := kgo.NewClient(kgo.SeedBrokers(os.Getenv("KAFKA_BOOTSTRAP_SERVERS")),
        kgo.ConsumerGroup(group), kgo.ConsumeTopics(topic), kgo.DisableAutoCommit(),
        kgo.ConsumeResetOffset(kgo.NewOffset().AtStart()))
    if err != nil { return nil, err }
    return &KafkaConsumer{client: client}, nil
}

func (c *KafkaConsumer) Close() { c.client.Close() }

// Handler must commit application state before returning. A failed handler leaves
// the offset uncommitted; durable idempotency must handle redelivery.
func (c *KafkaConsumer) Process(ctx context.Context, handler func(context.Context, *kgo.Record) error) error {
    for ctx.Err() == nil {
        fetches := c.client.PollFetches(ctx)
        if err := fetches.Err(); err != nil { return err }
        for _, record := range fetches.Records() {
            headers := kafkaHeaders(record.Headers)
            linked := propagation.TraceContext{}.Extract(context.Background(), &headers)
            linkedContext := trace.SpanContextFromContext(linked)
            options := []trace.SpanStartOption{trace.WithSpanKind(trace.SpanKindConsumer)}
            if linkedContext.IsValid() { options = append(options, trace.WithLinks(trace.Link{SpanContext: linkedContext})) }
            processCtx, span := otel.Tracer("mobilis.kafka").Start(ctx, "kafka process", options...)
            err := handler(processCtx, record)
            if err != nil { span.RecordError(err); span.End(); return err }
            span.End()
            if err := c.client.CommitRecords(ctx, record); err != nil { return err }
        }
    }
    return ctx.Err()
}
