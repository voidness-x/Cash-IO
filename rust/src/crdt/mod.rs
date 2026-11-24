use serde::{Deserialize, Serialize};
use std::cmp::Ordering;
use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum EntityType {
    Account,
    Transaction,
    Envelope,
    Attachment,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ActionType {
    Create,
    Update,
    SoftDelete, // Tombstone to prevent resurrecting deleted records
}

/// An immutable mutation event in the distributed CRDT event-sourcing log.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MutationEvent {
    pub event_id: Uuid,
    pub device_id: Uuid,
    pub lamport_clock: u64,
    pub entity_type: EntityType,
    pub entity_id: Uuid,
    pub action: ActionType,
    pub payload_json: String,
    pub timestamp_ms: i64,
}

impl MutationEvent {
    pub fn new(
        device_id: Uuid,
        lamport_clock: u64,
        entity_type: EntityType,
        entity_id: Uuid,
        action: ActionType,
        payload_json: String,
        timestamp_ms: i64,
    ) -> Self {
        Self {
            event_id: Uuid::new_v4(),
            device_id,
            lamport_clock,
            entity_type,
            entity_id,
            action,
            payload_json,
            timestamp_ms,
        }
    }
}

/// Total deterministic ordering for CRDT events:
/// 1. Higher Lamport Clock wins.
/// 2. If Lamport Clocks are equal, Device UUID serves as a deterministic tie-breaker.
impl Ord for MutationEvent {
    fn cmp(&self, other: &Self) -> Ordering {
        match self.lamport_clock.cmp(&other.lamport_clock) {
            Ordering::Equal => self.device_id.cmp(&other.device_id),
            ord => ord,
        }
    }
}

impl PartialOrd for MutationEvent {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

/// Audit log record generated whenever concurrent edits are merged.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MergeAuditRecord {
    pub timestamp_ms: i64,
    pub entity_id: Uuid,
    pub entity_type: EntityType,
    pub winning_device: Uuid,
    pub losing_device: Uuid,
    pub lamport_clock: u64,
}

pub struct CrdtMergeEngine;

impl CrdtMergeEngine {
    /// Merges remote event logs into the local log deterministically.
    /// Returns the combined ordered log and any audit records for conflicting updates.
    pub fn merge_events(
        mut local_events: Vec<MutationEvent>,
        remote_events: Vec<MutationEvent>,
    ) -> (Vec<MutationEvent>, Vec<MergeAuditRecord>) {
        let mut audit_records = Vec::new();
        let mut existing_ids: std::collections::HashSet<Uuid> =
            local_events.iter().map(|e| e.event_id).collect();

        for remote in remote_events {
            if !existing_ids.contains(&remote.event_id) {
                // Check if this modifies an entity that was also modified concurrently
                for local in &local_events {
                    if local.entity_id == remote.entity_id && local.action == ActionType::Update && remote.action == ActionType::Update {
                        let (winner, loser) = if remote > *local {
                            (remote.device_id, local.device_id)
                        } else {
                            (local.device_id, remote.device_id)
                        };

                        audit_records.push(MergeAuditRecord {
                            timestamp_ms: chrono::Utc::now().timestamp_millis(),
                            entity_id: remote.entity_id,
                            entity_type: remote.entity_type,
                            winning_device: winner,
                            losing_device: loser,
                            lamport_clock: std::cmp::max(remote.lamport_clock, local.lamport_clock),
                        });
                    }
                }

                existing_ids.insert(remote.event_id);
                local_events.push(remote);
            }
        }

        // Sort deterministically by Lamport Clock + Device ID
        local_events.sort();
        (local_events, audit_records)
    }
}
